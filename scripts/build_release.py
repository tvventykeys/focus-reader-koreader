#!/usr/bin/env python3
"""Build one versioned, installable KOReader plugin ZIP from checked-in sources."""
from pathlib import Path
import hashlib
import os
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT / "focusreader.koplugin"
DIST = ROOT / "dist" / "release"
DIST.mkdir(parents=True, exist_ok=True)

# A tagged release always uses its tag. Development runs use VERSION.
tag = os.environ.get("GITHUB_REF_NAME") if os.environ.get("GITHUB_REF_TYPE") == "tag" else None
version = (tag or (ROOT / "VERSION").read_text(encoding="utf-8").strip())
if not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?", version):
    raise ValueError(f"Invalid Focus Reader version: {version!r}")

output = DIST / f"Focus-Reader-{version}-koplugin.zip"
# Only publish the current build in Actions. Old checked-in dist/*.zip
# files cannot accidentally end up in a newer release artifact.
for previous in DIST.glob("*.zip"):
    previous.unlink()
for previous in DIST.glob("*.sha256"):
    previous.unlink()

with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for file in sorted(PLUGIN.rglob("*")):
        if file.is_file():
            archive.write(file, file.relative_to(ROOT).as_posix())
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    assert "focusreader.koplugin/main.lua" in archive.namelist()

sha = hashlib.sha256(output.read_bytes()).hexdigest()
(output.parent / (output.name + ".sha256")).write_text(
    sha + "  " + output.name + "\n", encoding="utf-8"
)
print("Built:", output)
print("SHA256:", sha)
