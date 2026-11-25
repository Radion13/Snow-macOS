#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
./scripts/build.sh Debug
./scripts/build.sh Release
swift test > build/logs/tests-p1.log 2>&1
binary="$PWD/build/Release/Snow.app/Contents/MacOS/Snow"
xcrun swiftc Sources/SnowCore/*.swift Sources/SnowApp/WindowGeometryProvider.swift scripts/platform-probe.swift -o build/platform-probe
build/platform-probe --hold-for-smoke > build/logs/platform-probe.json 2> build/logs/platform-probe.stderr &
probe_pid=$!
trap 'kill "$probe_pid" 2>/dev/null || true' EXIT
"$binary" --smoke-test > build/logs/smoke-p1.json
wait "$probe_pid"
trap - EXIT
"$binary" --feature-check > build/logs/features-release.json
python3 - <<'PY'
import json
from pathlib import Path
for name in ['smoke-p1.json', 'features-release.json', 'platform-probe.json']:
    values = json.loads((Path('build/logs') / name).read_text())
    failed = [key for key, value in values.items() if value is not True]
    if not values or failed:
        raise SystemExit(f'{name}: failed {failed}')
    print(f'{name}: {len(values)} checks passed')
PY
codesign --verify --strict build/Release/Snow.app
lipo -archs build/Release/Snow.app/Contents/MacOS/Snow
