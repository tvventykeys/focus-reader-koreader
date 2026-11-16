#!/usr/bin/env python3
"""Fail closed unless a Focus Reader release ZIP exactly matches its source tree."""

from __future__ import annotations

import hashlib
import os
from pathlib import Path
import re
import sys
from zipfile import BadZipFile, ZipFile

ROOT = Path(__file__).resolve().parents[1]
VERSION_PATTERN = re.compile(r"v[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?\Z")


class ReleaseValidationError(ValueError):
    """An archive, version, or checksum is not safe to publish."""


def verify_release(root: Path, tag: str | None = None) -> tuple[str, int, str]:
    root = Path(root)
    version_path = root / "VERSION"
    if not version_path.is_file():
        raise ReleaseValidationError("Missing VERSION file")
    version = version_path.read_text(encoding="utf-8").strip()
    if not VERSION_PATTERN.fullmatch(version):
        raise ReleaseValidationError(f"Invalid VERSION: {version!r}")
    if tag is not None and version != tag:
        raise ReleaseValidationError(f"Tag {tag!r} != source VERSION {version!r}")

    source_root = root / "focusreader.koplugin"
    if not source_root.is_dir():
        raise ReleaseValidationError("Missing focusreader.koplugin directory")
    source_files = sorted(p for p in source_root.rglob("*") if p.is_file())
    expected = {
        p.relative_to(root).as_posix(): p
        for p in source_files
    }
    for required in ("focusreader.koplugin/main.lua", "focusreader.koplugin/_meta.lua"):
        if required not in expected:
            raise ReleaseValidationError(f"Missing required plugin source: {required}")

    dist = root / "dist" / "release"
    package = dist / f"Focus-Reader-{version}-koplugin.zip"
    checksum_file = dist / f"{package.name}.sha256"
    zip_files = sorted(dist.glob("*.zip"))
    checksum_files = sorted(dist.glob("*.sha256"))
    if zip_files != [package] or checksum_files != [checksum_file]:
        raise ReleaseValidationError(
            "Release directory must contain exactly one version-matched ZIP and SHA256 file"
        )
    if not package.is_file() or not checksum_file.is_file():
        raise ReleaseValidationError("Missing ZIP or checksum")

    try:
        with ZipFile(package, "r") as archive:
            names = archive.namelist()
            if len(names) != len(set(names)):
                raise ReleaseValidationError("Duplicate file names in archive")
            if set(names) != set(expected):
                missing = sorted(set(expected) - set(names))
                extra = sorted(set(names) - set(expected))
                raise ReleaseValidationError(f"Archive contents differ: missing={missing}, extra={extra}")
            bad = archive.testzip()
            if bad:
                raise ReleaseValidationError(f"Archive CRC failed for {bad}")
            for name, source in expected.items():
                if archive.read(name) != source.read_bytes():
                    raise ReleaseValidationError(f"Packaged file does not match source: {name}")
    except (BadZipFile, OSError) as exc:
        raise ReleaseValidationError(f"Cannot verify release ZIP: {exc}") from exc

    digest = hashlib.sha256(package.read_bytes()).hexdigest()
    expected_checksum = f"{digest}  {package.name}\n"
    if checksum_file.read_text(encoding="utf-8") != expected_checksum:
        raise ReleaseValidationError("SHA256 file does not match the release ZIP")
    return version, len(expected), digest


def main() -> int:
    tag = os.environ.get("GITHUB_REF_NAME") if os.environ.get("GITHUB_REF_TYPE") == "tag" else None
    try:
        version, count, digest = verify_release(ROOT, tag)
    except (ReleaseValidationError, OSError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    print(f"PASS: {version}: {count} source files exactly match ZIP; SHA256 {digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
