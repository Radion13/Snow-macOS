#!/usr/bin/env python3
"""Reuse only the project's own icon and winter scenes, never reference images."""
import pathlib
import shutil
import struct
ROOT = pathlib.Path(__file__).resolve().parents[1]
MAC = ROOT.parent
frames = []
for size in [16, 32, 128, 256]:
    path = MAC / ('build/Snow.iconset/icon_%dx%d.png' % (size, size))
    if path.exists():
        frames.append((size, path.read_bytes()))
if frames:
    offset = 6 + 16 * len(frames)
    icon = bytearray(struct.pack('<HHH', 0, 1, len(frames)))
    for size, data in frames:
        icon += struct.pack('<BBBBHHII', size % 256, size % 256, 0, 0, 1, 32, len(data), offset)
        offset += len(data)
    for _, data in frames:
        icon += data
    (ROOT / 'assets/snow.ico').write_bytes(icon)
elif not (ROOT / 'assets/snow.ico').is_file():
    raise SystemExit('Original project icon missing from assets/snow.ico')
for name in ['cabin.png', 'porch.png']:
    source = MAC / 'build/previews-0.2.4' / name
    if source.exists():
        shutil.copy2(source, ROOT / 'assets' / name)
    elif not (ROOT / 'assets' / name).is_file():
        raise SystemExit('Own scene preview missing: ' + str(source))
print('Prepared original ICO and two winter scenes')
