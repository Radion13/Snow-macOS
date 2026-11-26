# macOS 0.3.9 validation

Checked on 26 November 2026 on Apple Silicon. Version 0.3.9, build 32.

| Check | Result |
| --- | --- |
| Core tests | 117 passed, including 8 new snowman variant tests |
| Feature and localization checks | 103 passed in Debug and Release |
| Snowman rendering checks | 12 passed in Debug and Release |
| Native UI checks | 20 passed; nine settings tabs and compact menu rendered |
| Debug and Release builds | Universal arm64 + x86_64 |
| Local signature | `codesign --verify --deep --strict` passed |
| DMG | Packaging and disk image integrity checks passed |

The compact menu uses a 0.8625 scale, a 24-point design gap below the header, and 16-point design gaps around dividers. Screen selection remains in full settings. The mitten and snowball toggle play directly, and Esc clears the selected tool. Garland light and palette use native popups. Snowman checks cover all four looks in both snow materials, stable redraws and display transfers, and advancing the appearance after rebuilding.

Production-rendered previews: [snowmen](images/snowmen.png), [compact menu](images/settings/menu.png), and the nine tabs linked in the [README](../README.md#interface-and-snowmen). See [design QA](design-qa.md) for scope and local log names. Native commands require a graphical macOS session and no other running instance of Snow.

Physical Intel hardware and macOS 12 were not tested. Universal compilation does not replace those checks. This update did not rerun the general lifecycle smoke suite; historical window-visibility results below are retained as evidence for 0.2.20. Builds use local ad-hoc signing.

## Historical macOS 0.2.20 validation

Checked on 25 November 2026 with Xcode 26.5 (17F42) and Swift 6.3.2 on Apple Silicon.

| Check | Result |
| --- | --- |
| Version | 0.2.20, build 22 |
| Debug and Release builds | Universal arm64 + x86_64 |
| Core tests | 109 passed, zero failures |
| Native feature checks on Apple Silicon | 91 passed, including 14 localization checks |
| Native feature checks through Rosetta | The same 91 passed |
| Localization catalogs | 167 keys per language; no missing or duplicate keys |
| Window geometry checks | 10 passed |
| General lifecycle and input smoke check | Final run: 14 of 16 passed; see limitations below |
| Local signature | `codesign --verify --strict` passed |
| Minimum deployment target | macOS 12.0 |
| DMG | Verified with `hdiutil verify`; mounted app binary matched Release |

Localization checks cover English as the default independently of the system language, invalid saved values, persistence, complete catalogs, both menus, checkmarks, settings-window titles, paused and hidden statuses, reset behavior, and preserving snow and settings.

Manual checks covered switching in both directions, keeping the current settings pane and selected values, segmented-control and popup labels, and Russian remaining selected after quitting and relaunching. The final language was set back to English.

## Remaining limitations

The general smoke test is not fully green. The final run did not pass `pauseStopsSimulationAndPassesInput` or `resume`, which inspect the visibility of all overlay windows. Both also failed on the unchanged 0.2.19 build in the same session. The initial comparison produced the same five failures on both versions; the final 0.2.20 run passed all game-input checks after manual verification. These visibility checks remain unresolved.

Physical Intel hardware and macOS 12 were not tested. Rosetta does not replace those checks. Builds use local ad-hoc signing without Developer ID signing or notarization.

## Reproduce

```sh
chmod +x scripts/*.sh
./scripts/build.sh Debug
./scripts/build.sh Release
swift test
./scripts/validate.sh
codesign --verify --strict build/Release/Snow.app
lipo -archs build/Release/Snow.app/Contents/MacOS/Snow
```

Quit other copies of Snow before native checks. They require a graphical macOS session and open temporary test windows. `validate.sh` can exit unsuccessfully when the visibility checks above fail; inspect the JSON reports in `build/logs/`.

To package the source yourself, run `./scripts/package.sh`. The checked local DMG had SHA-256 `1cbfa3f646d49a128b48058534afc848aebeda7912504f63d441f63bbc155b02`. A newly generated or newly signed disk image can have a different hash.
