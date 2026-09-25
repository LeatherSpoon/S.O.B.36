"""Read-only private inventory contract; fixtures contain no commercial content."""

import hashlib
from contextlib import closing
import importlib.util
import json
import os
from pathlib import Path
from types import SimpleNamespace
import stat
import sqlite3
import subprocess
import tempfile
import unittest
from unittest import mock

from PIL import Image


class ScanInventoryTests(unittest.TestCase):
    def setUp(self):
        scratch = Path(__file__).resolve().parents[1] / ".local"
        scratch.mkdir(exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="scan-test-", dir=scratch)
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.source = self.base / "source"
        self.source.mkdir()
        self.output = self.base / "private" / "manifest.json"
        self.checkpoint = self.base / "private" / "checkpoint.sqlite3"

    def tool(self):
        try:
            spec = importlib.util.find_spec("tools.scan_inventory.inventory")
        except ModuleNotFoundError:
            spec = None
        self.assertIsNotNone(spec, "scan inventory implementation is missing")
        from tools.scan_inventory import inventory
        return inventory

    def write(self, name, data=b"placeholder"):
        target = self.source / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        return target

    def scan(self, **options):
        return self.tool().run_inventory(
            self.source, self.output, checkpoint=self.checkpoint, **options
        )

    def test_collects_deterministic_metadata_without_changing_sources(self):
        image = self.source / "Hero" / "sample.PNG"
        image.parent.mkdir()
        Image.new("RGB", (7, 5), "blue").save(image)
        other = self.write("z.txt", b"fixture")
        before = {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in (image, other)}
        manifest = self.scan()
        self.assertEqual(manifest["schema_version"], 1)
        records = manifest["files"]
        self.assertEqual([r["relative_path"] for r in records], ["Hero/sample.PNG", "z.txt"])
        record = records[0]
        self.assertEqual(record["extension"], ".png")
        self.assertEqual(record["dimensions"], {"width": 7, "height": 5})
        self.assertEqual(record["byte_size"], image.stat().st_size)
        self.assertEqual(record["sha256"], hashlib.sha256(image.read_bytes()).hexdigest())
        self.assertEqual(record["provisional_category"], "hero")
        self.assertEqual(record["confidence"], "imported")
        self.assertEqual(record["processing_status"], "complete")
        self.assertIsNone(record["duplicate_group_id"])
        self.assertEqual(records[1]["dimensions"], None)
        first_output = self.output.read_bytes()
        self.scan()
        self.assertEqual(first_output, self.output.read_bytes())
        for path, (data, mtime) in before.items():
            self.assertEqual((path.read_bytes(), path.stat().st_mtime_ns), (data, mtime))
        self.assertEqual(sorted(p.relative_to(self.source).as_posix() for p in self.source.rglob("*") if p.is_file()), ["Hero/sample.PNG", "z.txt"])

    def test_duplicate_ids_are_hash_based_and_disappear_after_deletion(self):
        self.write("a.dat", b"same")
        second = self.write("nested/b.dat", b"same")
        self.write("c.dat", b"other")
        manifest = self.scan()
        records = {r["relative_path"]: r for r in manifest["files"]}
        expected = "sha256:" + hashlib.sha256(b"same").hexdigest()
        self.assertEqual(records["a.dat"]["duplicate_group_id"], expected)
        self.assertEqual(records["nested/b.dat"]["duplicate_group_id"], expected)
        self.assertIsNone(records["c.dat"]["duplicate_group_id"])
        second.unlink()
        self.assertTrue(all(r["duplicate_group_id"] is None for r in self.scan()["files"]))

    def test_resume_reuses_unchanged_files_but_invalidates_changed_content(self):
        target = self.write("a.dat", b"first")
        self.scan()
        inventory = self.tool()
        with mock.patch.object(inventory, "hash_file", side_effect=AssertionError("rehash")):
            self.assertEqual(self.scan()["files"][0]["sha256"], hashlib.sha256(b"first").hexdigest())
        old_mtime = target.stat().st_mtime_ns
        target.write_bytes(b"second")
        os.utime(target, ns=(old_mtime, old_mtime))
        self.assertEqual(self.scan()["files"][0]["sha256"], hashlib.sha256(b"second").hexdigest())
        with mock.patch.object(inventory, "hash_file", wraps=inventory.hash_file) as hasher:
            self.scan(resume=False)
            self.assertEqual(hasher.call_count, 1)

    def test_resume_is_bound_to_source_and_never_promotes_confidence(self):
        self.write("a.dat", b"fixture")
        self.scan()
        with closing(sqlite3.connect(self.checkpoint)) as connection:
            row = connection.execute("SELECT record FROM entries WHERE relative_path = ?", ("a.dat",)).fetchone()
            record = json.loads(row[0])
            record["confidence"] = "verified"
            connection.execute("UPDATE entries SET record = ? WHERE relative_path = ?", (json.dumps(record), "a.dat"))
            connection.commit()
        self.assertEqual(self.scan()["files"][0]["confidence"], "imported")
        second_root = self.base / "source_two"
        second_root.mkdir()
        (second_root / "a.dat").write_bytes(b"different")
        result = self.tool().run_inventory(second_root, self.output, checkpoint=self.checkpoint)
        self.assertEqual(result["files"][0]["sha256"], hashlib.sha256(b"different").hexdigest())

    def test_corrupt_image_and_unreadable_file_do_not_abort_and_errors_retry(self):
        self.write("bad.png", b"not an image")
        self.write("denied.dat")
        self.write("good.txt")
        inventory = self.tool()
        real_hash = inventory.hash_file

        def deny_one(path):
            if Path(path).name == "denied.dat":
                raise PermissionError(13, "private absolute path must not leak")
            return real_hash(path)

        with mock.patch.object(inventory, "hash_file", side_effect=deny_one):
            records = {r["relative_path"]: r for r in self.scan()["files"]}
        self.assertEqual(records["denied.dat"]["processing_status"], "error")
        self.assertEqual(records["bad.png"]["processing_status"], "error")
        self.assertIsNotNone(records["bad.png"]["sha256"])
        self.assertEqual(records["good.txt"]["processing_status"], "complete")
        self.assertNotIn("private absolute", self.output.read_text())
        records = {r["relative_path"]: r for r in self.scan()["files"]}
        self.assertEqual(records["denied.dat"]["processing_status"], "complete")

    def test_restart_retains_completed_work_after_interruption(self):
        self.write("a.dat")
        self.write("b.dat")
        inventory = self.tool()
        real_hash = inventory.hash_file

        def interrupt_second(path):
            if Path(path).name == "b.dat":
                raise KeyboardInterrupt
            return real_hash(path)

        with mock.patch.object(inventory, "hash_file", side_effect=interrupt_second):
            with self.assertRaises(KeyboardInterrupt):
                self.scan()
        self.assertFalse(self.output.exists())
        with mock.patch.object(inventory, "hash_file", wraps=real_hash) as hasher:
            self.assertEqual(len(self.scan()["files"]), 2)
            self.assertEqual(hasher.call_count, 1)

    def test_output_and_checkpoint_inside_source_are_rejected_before_writes(self):
        original = self.write("original.dat")
        inventory = self.tool()
        with self.assertRaises(ValueError):
            inventory.run_inventory(self.source, original)
        with self.assertRaises(ValueError):
            inventory.run_inventory(self.source, self.output, checkpoint=self.source / "nested" / "cache.db")
        self.assertFalse(self.output.parent.exists())
        self.assertFalse((self.source / "nested").exists())
        self.assertEqual(original.read_bytes(), b"placeholder")
        with self.assertRaises(ValueError):
            inventory.run_inventory(self.source, self.output, checkpoint=self.output)

    def test_links_are_not_followed_and_output_links_are_rejected(self):
        outside = self.base / "outside"
        outside.mkdir()
        (outside / "secret.dat").write_bytes(b"outside")
        link = self.source / "linked"
        self.directory_link(link, outside)
        records = self.scan()["files"]
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0]["relative_path"], "linked")
        self.assertEqual(records[0]["processing_status"], "skipped")
        self.assertIsNone(records[0]["sha256"])
        output_link = self.base / "redirect"
        self.directory_link(output_link, self.source)
        with self.assertRaises(ValueError):
            self.tool().run_inventory(self.source, output_link / "manifest.json")
        with self.assertRaises(ValueError):
            self.tool().run_inventory(link, self.output)

    def directory_link(self, path, target):
        try:
            path.symlink_to(target, target_is_directory=True)
        except OSError:
            if os.name != "nt":
                raise
            environment = dict(os.environ, SOB_TEST_LINK=str(path), SOB_TEST_TARGET=str(target))
            subprocess.run([
                "powershell", "-NoProfile", "-NonInteractive", "-Command",
                "New-Item -ItemType Junction -Path $env:SOB_TEST_LINK -Target $env:SOB_TEST_TARGET -ErrorAction Stop | Out-Null",
            ], env=environment, check=True, capture_output=True)

    def test_unreadable_directory_is_reported_and_other_files_continue(self):
        self.write("denied/inside.dat")
        self.write("good.dat")
        inventory = self.tool()
        real_scandir = os.scandir

        def deny_one(path):
            if Path(path).name == "denied":
                raise PermissionError(13, "fixture")
            return real_scandir(path)

        with mock.patch.object(inventory.os, "scandir", side_effect=deny_one):
            result = self.scan()
        self.assertEqual([record["relative_path"] for record in result["files"]], ["good.dat"])
        self.assertEqual(result["scan_errors"], [{"relative_path": "denied", "stage": "list", "type": "PermissionError", "errno": 13}])

    def test_changed_during_hash_is_reported_and_not_cached_as_complete(self):
        target = self.write("a.dat", b"first")
        inventory = self.tool()
        real_hash = inventory.hash_file

        def mutate_after_hash(path):
            digest = real_hash(path)
            target.write_bytes(b"changed")
            return digest

        with mock.patch.object(inventory, "hash_file", side_effect=mutate_after_hash):
            record = self.scan()["files"][0]
        self.assertEqual(record["processing_status"], "error")
        self.assertIsNone(record["sha256"])
        self.assertEqual(self.scan()["files"][0]["sha256"], hashlib.sha256(b"changed").hexdigest())

    def test_hardlinked_checkpoint_cannot_modify_source(self):
        original = self.write("original.dat")
        self.checkpoint.parent.mkdir()
        os.link(original, self.checkpoint)
        with self.assertRaises(ValueError):
            self.scan()
        self.assertEqual(original.read_bytes(), b"placeholder")

    def test_reparse_entries_are_skipped_without_opening(self):
        self.write("cloud.dat")
        inventory = self.tool()
        real_check = inventory.is_link_or_reparse
        with mock.patch.object(inventory, "is_link_or_reparse", side_effect=lambda path: Path(path).name == "cloud.dat" or real_check(path)):
            with mock.patch.object(inventory, "hash_file", side_effect=AssertionError("opened reparse point")):
                record = self.scan()["files"][0]
        self.assertEqual(record["processing_status"], "skipped")

    def test_cloud_reparse_tags_are_readable_but_name_surrogates_are_blocked(self):
        inventory = self.tool()
        for tag in (0x9000001A, 0x9000101A, 0x9000F01A):
            info = SimpleNamespace(st_mode=stat.S_IFREG, st_file_attributes=0x400, st_reparse_tag=tag)
            with mock.patch.object(Path, "lstat", return_value=info):
                self.assertFalse(inventory.is_link_or_reparse(Path("cloud")))
        for tag in (0xA0000003, 0xA000000C, 0x8000001B, 0):
            info = SimpleNamespace(st_mode=stat.S_IFREG, st_file_attributes=0x400, st_reparse_tag=tag)
            with mock.patch.object(Path, "lstat", return_value=info):
                self.assertTrue(inventory.is_link_or_reparse(Path("blocked")))

    def test_source_resolution_explicit_then_environment_then_local_config(self):
        inventory = self.tool()
        config = self.base / "config.json"
        config.write_text(json.dumps({"source_root": str(self.source)}))
        with mock.patch.dict(os.environ, {"SOB_SOURCE_ROOT": str(self.base / "env")}, clear=True):
            self.assertEqual(inventory.resolve_source(self.source, config), self.source)
            self.assertEqual(inventory.resolve_source(None, config), self.base / "env")
        with mock.patch.dict(os.environ, {}, clear=True):
            self.assertEqual(inventory.resolve_source(None, config), self.source)
            with self.assertRaises(ValueError):
                inventory.resolve_source(None, None)


if __name__ == "__main__":
    unittest.main()
