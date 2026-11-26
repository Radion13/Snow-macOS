# Third-party notices

Snow uses the operating system's Win32, GDI+, WIC, DWM and Shell APIs. It
does not redistribute Windows DLLs or fonts. The vector illustrations,
icon and two winter scenes come from this project's existing artwork.

The executable is compiled with Zig and LLVM libc++/compiler-rt. Relevant
license notices are provided in `licenses`. Build tools are kept separately
in `.tools` and are not installed with the application.

- Zig: https://ziglang.org/ and https://github.com/ziglang/zig
- LLVM: https://llvm.org/ and https://github.com/llvm/llvm-project
- NSIS installer: https://nsis.sourceforge.io/ and
  https://github.com/electron-userland/electron-builder-binaries

NSIS is used for the per-user installer and uninstaller. Its license notice
is included with the application. No external analytics or update service
is connected to this Windows build.
