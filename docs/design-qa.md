# macOS design QA — Snow 0.3.9

final result: passed

## Scope

Four vector snowman looks based on the supplied references: festive red hat and dotted scarf, blue knitwear and broom, bucket and blue scarf, and red mittens with a raised arm. Remove by from the creator credit while retaining its Telegram link.

## Selection and model validation

- 117 SnowCore tests passed, including eight new tests for the four-step cycle, shared ordering across games/displays, incomplete stacks, stable redraw/window movement, reassembly, display transfer, clear and independent settings previews.
- The shared cycle has a random starting look and advances without consecutive repeats. Appearance belongs to the completed head identity and is transferred with the game objects.
- Physics, snow consumption, stack limits and support mechanics retain their existing behavior.

## Native rendering and UI validation

- 12 snowman rendering checks passed in Debug and Release: all four looks render their eyes, carrot and smile under sibling batching in simple and textured snow; expected accessories exist and redraw preserves appearance.
- 103 feature/localization checks passed in both Debug and Release, including the extended crop mask, bucket handle, scarf, material switching, trees and garlands.
- 20 native UI checks passed. Reviewed the General render showing от D1on without an underline. Link destination remains https://t.me/Radion013.
- The four-person gallery and individual previews are generated from the actual production renderer, not separate mockups.
- Crop bounds are cached from the complete vector artwork, including broom, hands, scarf and feet. Existing foreground-window clipping is retained.
- Universal arm64/x86_64 build, strict signature verification and DMG integrity verification passed.

Gallery: build/snowmen-0.3.9/snowmen.png.
Settings renders: build/settings-previews-0.3.9/.
Logs: build/logs/core-tests-0.3.9.log, snowmen-release-0.3.9.log, features-release-0.3.9.log and settings-ui-0.3.9.log.
Package: build/Snow-0.3.9-universal.dmg.

Runtime and graphics verification used this Apple Silicon Mac; separate Intel and macOS 12 hardware were not tested.
