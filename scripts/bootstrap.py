#!/usr/bin/env python3
"""Pinned, project-local macOS toolchain. No global installation."""
import hashlib
import pathlib
import platform
import sys
import tarfile
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
TOOLS = ROOT / '.tools'
TOOLS.mkdir(exist_ok=True)
PACKAGES = [
    ('zig-0.17.1.tar.xz', 'https://ziglang.org/download/0.17.1/zig-aarch64-macos-0.17.1.tar.xz',
     '75f1bc7a1e9852f17ec9a0c1895f767c4ec56d46bc8a834920eece1d0359dd8d', 'zig-aarch64-macos-0.17.1'),
    ('nsis.tar.gz', 'https://github.com/electron-userland/electron-builder-binaries/releases/download/nsis%402.0.4/nsis-bundle-3.13.tar.gz',
     'c18e9ad9684cf4c5bbd7b768cbf1b056d40771d7bd9ae1b513346452decf89d2', 'nsis'),
]
if '--wine' in sys.argv:
    PACKAGES.append(('wine-full-11.21.tar.xz', 'https://github.com/Gcenx/macOS_Wine_builds/releases/download/11.21/wine-devel-11.21-osx64.tar.xz',
                     '9909b486657e10ab66c7279371ae1f990345b596b3b1b3a0cf21f28af24fa0ce', 'wine-full'))
if platform.system() != 'Darwin' or platform.machine() != 'arm64':
    raise SystemExit('This bootstrap targets Apple Silicon macOS. See README for Windows builds.')
for name, url, expected, folder in PACKAGES:
    archive = TOOLS / name
    if not archive.exists():
        print('Downloading ' + name, flush=True)
        request = urllib.request.Request(url, headers={'User-Agent': 'Snow-Windows-build/1'})
        partial = archive.with_name(archive.name + '.partial')
        with urllib.request.urlopen(request, timeout=60) as response, partial.open('wb') as output:
            while True:
                block = response.read(1024 * 1024)
                if not block:
                    break
                output.write(block)
        partial.replace(archive)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    if digest != expected:
        raise SystemExit('Checksum mismatch: ' + name)
    marker = TOOLS / (name + '.extracted')
    if not marker.exists():
        destination = TOOLS if name.startswith('zig') else TOOLS / folder
        destination.mkdir(exist_ok=True)
        with tarfile.open(archive) as source:
            for member in source.getmembers():
                target = (destination / member.name).resolve()
                if destination.resolve() not in target.parents and target != destination.resolve():
                    raise SystemExit('Unsafe archive path')
            source.extractall(destination)
        marker.touch()
    print(name + ': SHA-256 verified', flush=True)
