# Publication snapshot validation

Checked on 25 November 2026 from the standalone macOS source directory prepared for publication.

| Check | Result |
| --- | --- |
| Final app source | Matches the working macOS 0.2.19 source byte for byte |
| Clean Release build | Passed with Xcode 26.5 (17F42), Swift 6.3.2 on Apple Silicon |
| Core tests | 109 passed, zero failures |
| Release architectures | arm64 and x86_64 |
| Local signature | `codesign --verify --strict` passed |
| Minimum deployment target | macOS 12.0 |
| Documentation links | All relative links resolve inside this snapshot |
| Publication contents | Source, tests, resources, build scripts, and app-rendered previews; no Windows files or build output |

The publication check rebuilt the app and ran the core tests. It did not repeat graphical integration diagnostics or test physical Intel hardware and macOS 12. The build is locally ad-hoc signed, without Developer ID signing or notarization.

To reproduce the build and model checks:

```sh
./scripts/build.sh Release
swift test
codesign --verify --strict build/Release/Snow.app
lipo -archs build/Release/Snow.app/Contents/MacOS/Snow
```
