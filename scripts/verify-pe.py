#!/usr/bin/env python3
"""Inspect the actual PE artifacts, imports/resources and distribution payload."""
import hashlib
import json
import pathlib
import struct
ROOT = pathlib.Path(__file__).resolve().parents[1]

def pe(path):
    data = path.read_bytes()
    if data[:2] != b'MZ':
        raise ValueError('Not a Windows executable: ' + str(path))
    start = struct.unpack_from('<I', data, 0x3c)[0]
    if data[start:start+4] != b'PE\0\0':
        raise ValueError('Missing PE header')
    machine, count, _, _, _, optional_size, _ = struct.unpack_from('<HHIIIHH', data, start+4)
    opt = start+24
    magic = struct.unpack_from('<H', data, opt)[0]
    dirs = opt + (112 if magic == 0x20b else 96)
    sections = []
    for index in range(count):
        s = opt + optional_size + index*40
        size, rva, raw_size, raw = struct.unpack_from('<IIII', data, s+8)
        sections.append((rva, max(size, raw_size), raw))
    def offset(rva):
        for base, size, raw in sections:
            if base <= rva < base+size:
                return raw+rva-base
        raise ValueError('Unmapped RVA: ' + str(rva))
    imports = []
    rva, size = struct.unpack_from('<II', data, dirs+8)
    if rva:
        pos = offset(rva)
        while any(struct.unpack_from('<IIIII', data, pos)):
            name = offset(struct.unpack_from('<I', data, pos+12)[0])
            imports.append(data[name:data.index(0, name)].decode('ascii'))
            pos += 20
    resource_rva = struct.unpack_from('<I', data, dirs+16)[0]
    resources = []
    if resource_rva:
        at = offset(resource_rva)
        named, ids = struct.unpack_from('<HH', data, at+12)
        for index in range(named+ids):
            name, _ = struct.unpack_from('<II', data, at+16+8*index)
            if not name & 0x80000000:
                resources.append(name)
    cert_rva, cert_size = struct.unpack_from('<II', data, dirs+32)
    return dict(machine=hex(machine), bits=64 if magic==0x20b else 32,
                subsystem=struct.unpack_from('<H', data, opt+68)[0],
                imports=imports, resource_types=resources, signed=bool(cert_rva and cert_size),
                bytes=len(data), sha256=hashlib.sha256(data).hexdigest())

application = ROOT/'dist/Snow/Snow.exe'
installer = ROOT/'dist/SnowSetup-0.2.19-win-x64.exe'
info = {'application': pe(application), 'installer': pe(installer)}
assert info['application']['machine']=='0x8664', 'Application must be native x64'
assert info['application']['subsystem']==2, 'Application must use the GUI subsystem'
assert info['installer']['machine']=='0x14c' and info['installer']['subsystem']==2, 'NSIS bootstrap must be a Windows GUI executable'
assert {3,14,16,24}.issubset(info['application']['resource_types']), 'Icon, version or manifest missing'
system = {'kernel32.dll','user32.dll','gdi32.dll','gdiplus.dll','shell32.dll','ole32.dll',
          'comctl32.dll','comdlg32.dll','advapi32.dll','dwmapi.dll','wtsapi32.dll',
          'windowscodecs.dll','msvcrt.dll','ucrtbase.dll','ntdll.dll','shlwapi.dll','oleaut32.dll'}
unexpected = [x for x in info['application']['imports'] if x.lower() not in system
              and not x.lower().startswith(('api-ms-win-', 'ext-ms-win-'))]
assert not unexpected, 'Non-system DLL dependencies: '+str(unexpected)
for f in ['assets/snow.ico','assets/cabin.png','assets/porch.png','assets/tree-vector.svg','INSTALL.txt','THIRD_PARTY.md']:
    assert (ROOT/'dist/Snow'/f).is_file(), 'Payload missing '+f
info['payload'] = [str(p.relative_to(ROOT/'dist/Snow')) for p in sorted((ROOT/'dist/Snow').rglob('*')) if p.is_file()]
(ROOT/'build/pe-verification.json').write_text(json.dumps(info,indent=2),encoding='utf-8')
(ROOT/'dist/SHA256SUMS.txt').write_text(
    info['installer']['sha256']+'  SnowSetup-0.2.19-win-x64.exe\n'+
    info['application']['sha256']+'  Snow/Snow.exe\n', encoding='ascii')
print('Verified x64 PE, resources, system DLL dependencies and installer payload')
print('Installer SHA-256: '+info['installer']['sha256'])
