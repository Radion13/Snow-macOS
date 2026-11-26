#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p build dist/Snow/assets dist/Snow/licenses
python3 scripts/bootstrap.py > build/bootstrap.log 2>&1
python3 scripts/prepare-assets.py
python3 scripts/generate-tree.py > build/tree-vector.expected
cmp build/tree-vector.expected src/tree-vector.inc
export ZIG_GLOBAL_CACHE_DIR="$PWD/.tools/zig-cache"
export ZIG_LOCAL_CACHE_DIR="$PWD/build/zig-cache"
tool="$PWD/.tools/zig-aarch64-macos-0.17.1/zig"
clang++ -std=c++17 -O2 -Wall -Wextra -Wpedantic tests/core_tests.cpp -o build/core_tests
build/core_tests > build/core-tests.log
"$tool" rc /fo build/resources.res src/resources.rc > build/resources.log 2>&1
"$tool" c++ src/main.cpp build/resources.res -target x86_64-windows-gnu -std=c++17 -municode -Wl,--subsystem,windows -O2 -static -s -luser32 -lgdi32 -lgdiplus -lcomctl32 -lshell32 -lole32 -lcomdlg32 -ldwmapi -lwtsapi32 -lwindowscodecs -luuid -ladvapi32 -o dist/Snow/Snow.exe > build/compile.log 2>&1
cp assets/snow.ico assets/cabin.png assets/porch.png dist/Snow/assets/
cp assets/tree-vector.svg dist/Snow/assets/
cp INSTALL.txt THIRD_PARTY.md dist/Snow/
cp .tools/zig-aarch64-macos-0.17.1/LICENSE dist/Snow/licenses/Zig.txt
if [[ -f .tools/zig-aarch64-macos-0.17.1/lib/libcxx/LICENSE.TXT ]]; then
 cp .tools/zig-aarch64-macos-0.17.1/lib/libcxx/LICENSE.TXT dist/Snow/licenses/LLVM.txt
fi
cp .tools/nsis/nsis-bundle/LICENSE dist/Snow/licenses/NSIS.txt
"$PWD/.tools/nsis/nsis-bundle/makensis" -V2 "-DAPPDIR=$PWD/dist/Snow" "-DOUTFILE=$PWD/dist/SnowSetup-0.3.9-win.6-x64.exe" installer/snow.nsi > build/installer.log 2>&1
python3 scripts/verify-pe.py
print "Created: $PWD/dist/SnowSetup-0.3.9-win.6-x64.exe"
