#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
./scripts/build.sh Release
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
stage="$(mktemp -d "$PWD/build/dmg.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
ditto build/Release/Snow.app "$stage/Snow.app"
cp INSTALL.md "$stage/INSTALL.md"
ln -s /Applications "$stage/Applications"
hdiutil create -quiet -ov -volname "Snow $version" -srcfolder "$stage" -format UDZO "build/Snow-$version-universal.dmg"
hdiutil verify -quiet "build/Snow-$version-universal.dmg"
print "Created: $PWD/build/Snow-$version-universal.dmg"
