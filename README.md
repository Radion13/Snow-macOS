# Snow for macOS ❄️

A small native menu bar app that turns your desktop into a winter playground. Snow falls over real windows, gathers into drifts, and can be rolled into snowballs and snowmen.

**Swift · AppKit · SwiftUI · SpriteKit · Apple Silicon & Intel**

[Русское описание](docs/README.ru.md) · [Installation and controls, in Russian](INSTALL.md)

![Five decorated vector trees growing from a snowbank](docs/images/trees.png)

*An app-rendered preview on a plain background. In normal use the overlay is transparent and your desktop remains visible.*

## What you can do

- Let snow settle on window tops, the bottom of the screen, and the Dock. Rounded edges shed excess snow, and drifts keep their uneven shape.
- Switch between simple and textured snow, or soft dots and eight patterned snowflake designs. Adjust snowfall, flake size, wind, and quality.
- Push snow around with the mitten, knock it off a window edge, pick it up, and roll snowballs. Stack three balls to build a snowman with a bucket hat.
- Flick a snowball toward the imaginary monitor glass: it bursts into a snowy splash that melts away.
- Send either of two animated tractors to clear the bottom drift, manually or automatically.
- Add three styles of full-width garlands with brightness and blink controls, plus five decorated trees that grow from the bottom edge in six changing layouts.
- Pause or hide the effects from the menu bar. Animation respects the system Reduce Motion setting.

The interface starts in **English**, with **Russian** available from the menu. Normal overlay mode passes clicks through to other apps; interactive play is an explicit mode. All settings and imported files stay on your Mac. There are no third-party packages, accounts, analytics, or backend services.

<details>
<summary>Patterned snowflake preview</summary>

![Patterned snowflakes rendered by the app on a plain background](docs/images/snowflakes.png)

</details>

## Choose your language

English is the default, regardless of your macOS language. Open the snowflake menu and choose **Language → Русский** to switch to Russian. Choose **Язык → English** to switch back.

Menus, open settings, status messages, and play hints update immediately. Your choice is saved between launches. Snow, selected settings, and the current settings pane stay in place. Resetting snow settings keeps your language choice.

See the [0.2.20 release notes](CHANGES_0.2.20.md) for the latest changes.

## Build and run

Use a Mac with the full Xcode application and its command-line tools selected. The core Swift package requires Swift 5.9 or later. The app targets **macOS 12+** and builds a **Universal binary for arm64 and x86_64**.

```sh
git clone https://github.com/Radion13/Snow-macOS.git
cd Snow-macOS
chmod +x scripts/*.sh
./scripts/build.sh Release
open build/Release/Snow.app
```

You can also open `Snow.xcodeproj` in Xcode, select the `Snow` scheme, and run it. The app lives in the menu bar rather than the Dock. Open the snowflake menu to access settings, pause, or quit. Press **Esc** to leave interactive play.

The build uses local ad-hoc signing; an Apple Developer membership is not needed to build from source. This repository does not contain a Developer ID-signed or notarized distribution.

## Tests and diagnostics

```sh
# Independent simulation and settings tests
swift test

# Debug app
./scripts/build.sh Debug

# Native integration and rendering checks
./scripts/validate.sh
```

Before running native diagnostics, quit any other copy of Snow: the app enforces a single running instance. Native checks require a logged-in graphical macOS session and create temporary test windows. Logs and preview images are written under `build/`.

The Swift package contains **SnowCore only**. Use the Xcode project to build the menu bar app.

## Make a DMG

```sh
./scripts/package.sh
```

This builds the app and creates `build/Snow-0.2.20-universal.dmg`, containing `Snow.app`, an Applications shortcut, and a bilingual installation guide. It verifies the disk image after creation. Installer signing and notarization are separate distribution steps.

## How it is built

| Path | Purpose |
| --- | --- |
| `Sources/SnowCore` | Snow simulation, surface geometry, interactions, settings, and tree layouts |
| `Sources/SnowApp` | Menu bar lifecycle, SwiftUI settings, window geometry, transparent overlays, and SpriteKit rendering |
| `Tests/SnowCoreTests` | Model and regression tests runnable with Swift Package Manager |
| `Resources` | App metadata, English and Russian strings, and the generated app icon |
| `scripts` | Build, diagnostics, resource measurement, icon generation, and DMG packaging |
| `docs/images` | Previews rendered by the app and the vector tree artwork exported from its paths |

Snow materials and vector artwork are generated locally and reused as shared textures. Tree placements come from six presets, avoiding layout work on each animation frame. The normal overlay observes window geometry without reading window titles or taking screenshots of other apps.

## Current scope

This is the **macOS source for version 0.2.20, build 22**. The Windows port and prebuilt installers are maintained separately and are not included here.

Builds and model checks have been run on Apple Silicon. Version 0.2.20 passed 109 core tests and 91 native feature checks, including 14 language checks; the same native checks passed through Rosetta. The [validation record](docs/VALIDATION.md) also documents two remaining window-visibility smoke checks. An Intel binary is included in Universal builds; testing on physical Intel Macs and macOS 12 remains outstanding. Multi-monitor and Dock geometry can depend on the macOS version and display configuration.

Some earlier features remain in the source but are hidden in the current interface: winter scenes, snow on widgets, snowflake preview icons, and custom images on tractor blades.
