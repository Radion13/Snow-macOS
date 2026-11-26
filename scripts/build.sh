#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
configuration="${1:-Release}"
if [[ "$configuration" != Debug && "$configuration" != Release ]]; then
  print -u2 'Usage: ./scripts/build.sh [Debug|Release]'
  exit 2
fi
mkdir -p build/logs
if [[ ! -f Resources/AppIcon.icns || scripts/make-icon.swift -nt Resources/AppIcon.icns ]]; then
  xcrun swift scripts/make-icon.swift build/Snow.iconset
  iconutil -c icns build/Snow.iconset -o Resources/AppIcon.icns
fi
log="build/logs/${configuration}.log"
if xcodebuild -project Snow.xcodeproj -scheme Snow -configuration "$configuration" -derivedDataPath build/DerivedData build >"$log" 2>&1; then
  print "Built: $PWD/build/$configuration/Snow.app"
else
  cat "$log"
  exit 1
fi
