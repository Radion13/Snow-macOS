# 0.2.20 — English and Russian interface

25 November 2026 · macOS build 22

- English is now the default, independently of the macOS language.
- Choose **Language → Русский** in the snowflake menu to switch to Russian, or **Язык → English** to switch back. The application menu has the same choices.
- Your language choice is saved between launches and kept when resetting snow settings.
- Menus, open settings, status messages, accessibility labels, and play hints update without restarting the app. Snow, settings values, and the current settings pane are preserved.
- English and Russian catalogs each contain 167 strings. English is also the development language, and the installer volume name is now in English.
- Native pickers refresh when changing language so segmented controls and popup choices do not keep old labels.
- Added 14 native localization checks, bringing the feature-check total to 91. All 109 core tests and all native feature checks passed on Apple Silicon; native checks also passed through Rosetta.

The final general smoke run passed 14 of 16 checks. Two window-visibility checks remain unresolved and also failed on the previous version in the same session. See the [validation record](docs/VALIDATION.md) for details and hardware-testing limits.

Build and packaging commands are in the [README](README.md). The macOS installer is generated locally as `build/Snow-0.2.20-universal.dmg`; binaries and the Windows port are not included in this source repository.
