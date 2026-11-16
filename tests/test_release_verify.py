"""Regression tests for rejecting incorrect Focus Reader release artifacts."""

import hashlib
from pathlib import Path
import sys
import tempfile
import unittest
from zipfile import ZIP_DEFLATED, ZipFile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from verify_release import ReleaseValidationError, verify_release


class VerifyReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.version = "v1.2.3-beta.6"
        (self.root / "VERSION").write_text(self.version + "\n", encoding="utf-8")
        plugin = self.root / "focusreader.koplugin"
        plugin.mkdir()
        (plugin / "main.lua").write_bytes(b"-- plugin\n")
        (plugin / "_meta.lua").write_bytes(b"return {}\n")
        (plugin / "logic.lua").write_bytes(b"-- logic\n")
        self.dist = self.root / "dist" / "release"
        self.dist.mkdir(parents=True)
        self.zip = self.dist / f"Focus-Reader-{self.version}-koplugin.zip"
        self.rebuild()

    def rebuild(self, extra=None):
        plugin = self.root / "focusreader.koplugin"
        with ZipFile(self.zip, "w", compression=ZIP_DEFLATED) as z:
            for p in sorted(plugin.rglob("*")):
                if p.is_file():
                    z.write(p, p.relative_to(self.root).as_posix())
            if extra:
                z.writestr(extra[0], extra[1])
        digest = hashlib.sha256(self.zip.read_bytes()).hexdigest()
        (self.dist / f"{self.zip.name}.sha256").write_text(
            f"{digest}  {self.zip.name}\n", encoding="utf-8"
        )

    def test_valid_package_and_matching_tag(self):
        version, count, digest = verify_release(self.root, self.version)
        self.assertEqual((version, count, len(digest)), (self.version, 3, 64))

    def test_wrong_tag_fails(self):
        with self.assertRaisesRegex(ReleaseValidationError, "Tag"):
            verify_release(self.root, "v1.2.2")

    def test_modified_zip_file_fails_even_with_correct_checksum(self):
        with ZipFile(self.zip, "w", compression=ZIP_DEFLATED) as z:
            for p in sorted((self.root / "focusreader.koplugin").rglob("*")):
                if p.is_file():
                    content = b"older code\n" if p.name == "main.lua" else p.read_bytes()
                    z.writestr(p.relative_to(self.root).as_posix(), content)
        digest = hashlib.sha256(self.zip.read_bytes()).hexdigest()
        (self.dist / f"{self.zip.name}.sha256").write_text(
            f"{digest}  {self.zip.name}\n", encoding="utf-8"
        )
        with self.assertRaisesRegex(ReleaseValidationError, "does not match source"):
            verify_release(self.root)

    def test_missing_source_file_fails(self):
        (self.root / "focusreader.koplugin" / "logic.lua").write_bytes(b"updated")
        with self.assertRaisesRegex(ReleaseValidationError, "does not match source"):
            verify_release(self.root)

    def test_extra_zip_entry_fails(self):
        self.rebuild(extra=("unexpected.txt", "oops"))
        with self.assertRaisesRegex(ReleaseValidationError, "Archive contents differ"):
            verify_release(self.root)

    def test_wrong_checksum_fails(self):
        (self.dist / f"{self.zip.name}.sha256").write_text("bad checksum\n", encoding="utf-8")
        with self.assertRaisesRegex(ReleaseValidationError, "SHA256"):
            verify_release(self.root)

    def test_multiple_zips_fail(self):
        (self.dist / "Focus-Reader-old-koplugin.zip").write_bytes(b"fake")
        with self.assertRaisesRegex(ReleaseValidationError, "exactly one"):
            verify_release(self.root)

    def test_missing_plugin_entrypoint_fails(self):
        (self.root / "focusreader.koplugin" / "main.lua").unlink()
        with self.assertRaisesRegex(ReleaseValidationError, "required plugin source"):
            verify_release(self.root)


if __name__ == "__main__":
    unittest.main()
