# Snow for Windows

This repository is the standalone Windows port: C++17, Win32, GDI+, CMake.
Windows work lives on the `windows` branch of Radion13/Snow-macOS; its root is
the Windows project. Push Windows fixes to this branch, not the macOS `main`.
The current app is 0.2.19-win.1, based on macOS 0.2.19. Later macOS UI and
snowman changes are not implemented here. Read README.md and docs/DEVELOPMENT.md.

## Work locally on Windows

- Use `rg` for exact searches. Use Semble for conceptual search when available,
  with this checkout as the repository; otherwise use narrow `rg` searches.
- Build and run model tests with
  `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Build-Windows.ps1`.
  It uses Visual Studio C++ and Windows SDK through CMake, stages the app in
  `dist-native/Snow`, and fails on build or test errors.
- Close the normal app before running native diagnostics:
  `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Test-Windows.ps1`.
  The default executable is the newly staged native build, not the old installer.
  Logs are under `build/diagnostics`. Do not terminate an unrelated application.
- To test an installed copy, pass
  `-Executable "$env:LOCALAPPDATA\Programs\Snow\Snow.exe"` to Test-Windows.ps1.
- Run `dist-native/Snow/Snow.exe --settings` to inspect the actual UI. Use
  available native computer-use tools on Windows to reproduce the user's steps.
  If desktop tools are unavailable, report that limit and use native diagnostics;
  do not claim that visual interaction was verified.
- Reproduce the reported bug before fixing it. Add a focused regression check
  for model behavior or extend the existing diagnostic path for Win32 behavior.
- Build and run relevant tests after changes. Report exact results and remaining
  manual checks, especially DPI, multiple monitors, taskbar, sleep and fullscreen.
- Preserve hidden-feature flags and saved settings. Avoid unrelated macOS ports
  or application redesigns while fixing a Windows bug.

## Source map

- `src/main.cpp`: windows, settings UI, tray, input and native diagnostics.
- `src/core.hpp`: simulation and interactions; `tests/core_tests.cpp`: core tests.
- `src/drawing.hpp`, `src/effects-drawing.inc`: rendering.
- `src/tree-vector.inc`: generated from `assets/tree-vector.svg` with
  `python scripts/generate-tree.py`; do not edit its paths by hand.
- `installer/snow.nsi`: per-user NSIS installer. Build outputs stay untracked.

The downloadable installer is the original 0.2.19-win.1 build for reproduction.
After a source fix, test the new native executable and identify it separately
from that installer. Never replace a released binary without updating its notes
and SHA-256 checksum.
