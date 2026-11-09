#!/usr/bin/env python3
"""Build installable .koplugin ZIP from local checked-in sources."""
from pathlib import Path
import zipfile, hashlib
ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT / 'focusreader.koplugin'
DIST = ROOT / 'dist'
DIST.mkdir(exist_ok=True)
output = DIST / 'Focus-Reader-v1.0.1-koplugin.zip'
with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for file in sorted(PLUGIN.rglob('*')):
        if file.is_file():
            z.write(file, file.relative_to(ROOT).as_posix())
with zipfile.ZipFile(output) as z:
    assert z.testzip() is None
    assert 'focusreader.koplugin/main.lua' in z.namelist()
sha = hashlib.sha256(output.read_bytes()).hexdigest()
(output.parent / (output.name + '.sha256')).write_text(sha + '  ' + output.name + '\n')
print('Built:', output)
print('SHA256:', sha)
