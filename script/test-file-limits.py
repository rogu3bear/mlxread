#!/usr/bin/env python3
"""Boundary and population tests for the local file-limit inventory."""

import importlib.util
from contextlib import contextmanager
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location("file_limits", Path(__file__).with_name("check-file-limits.py"))
limits = importlib.util.module_from_spec(spec)
spec.loader.exec_module(limits)


class FileLimitTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def write(self, name, data):
        path = Path(name)
        (self.root / path).parent.mkdir(parents=True, exist_ok=True)
        (self.root / path).write_bytes(data)
        return limits.classify(self.root, path)

    def test_physical_lines_include_blank_comments_and_final_line(self):
        self.assertEqual(self.write("source.py", b"")[1], 0)
        self.assertEqual(self.write("source.py", b"# comment\n\nlast")[1], 3)
        self.assertEqual(self.write("source.py", b"# comment\n\nlast\n")[1], 3)
        self.assertEqual(self.write("source.py", b"one\r\ntwo\r\n")[1], 2)

    def test_text_cap_counts_unterminated_final_line(self):
        self.assertEqual(self.write("source.swift", b"\n" * 2000)[0], "TEXT")
        self.assertEqual(self.write("source.swift", b"\n" * 2000 + b"last")[0], "OVER")

    def test_instruction_cap_and_names(self):
        for name in ("AGENTS.md", "CLAUDE.md", "SKILL.md", ".cursor/rules/test.mdc",
                     ".github/instructions/test.instructions.md"):
            with self.subTest(name=name):
                self.assertEqual(self.write(name, b"\n" * 799)[0], "TEXT")
                self.assertEqual(self.write(name, b"\n" * 799 + b"last")[0], "OVER")

    def test_generated_exception_is_exact_and_still_measured(self):
        result = self.write("website/Cargo.lock", b"\n" * 2382)
        self.assertEqual(result[:2], ("EXEMPT", 2382))
        self.assertEqual(self.write("another/Cargo.lock", b"\n" * 2001)[0], "OVER")
        self.assertEqual(self.write("MLXRead/Resources/Info.plist", b"\n" * 2001)[0], "OVER")

    def test_binary_exclusion_is_bounded_and_checks_png_signature(self):
        png = b"\x89PNG\r\n\x1a\n\0"
        self.assertEqual(self.write("website/assets/icon.png", png)[0], "BINARY")
        self.assertEqual(self.write("elsewhere/icon.png", png)[0], "UNRESOLVED")
        self.assertEqual(self.write("website/assets/icon.png", b"\0not PNG")[0], "UNRESOLVED")
        self.assertEqual(self.write("blob.dat", b"\0")[0], "UNRESOLVED")

    def test_private_files_are_not_opened_but_examples_are_measured(self):
        # Missing credentials still classify before any attempt to open them.
        for name in (".env", "website/.env.local", ".dev.vars", "key.pem"):
            self.assertEqual(limits.classify(self.root, Path(name))[0], "PRIVATE")
        self.assertEqual(self.write("website/.env.example", b"TOKEN=\n")[0], "TEXT")

    def test_finder_metadata_requires_exact_name_and_signature(self):
        signature = b"\x00\x00\x00\x01Bud1"
        self.assertEqual(self.write(".DS_Store", signature + b"\0records")[0], "BINARY")
        self.assertEqual(self.write("nested/.DS_Store", signature)[0], "BINARY")
        for data in (b"", signature[:7], b"\x00\x00\x00\x02Bud1", b"authored text\n"):
            self.assertEqual(self.write(".DS_Store", data)[0], "UNRESOLVED")
        self.assertEqual(self.write("source.dat", signature)[0], "UNRESOLVED")

    def test_finder_metadata_reads_only_the_signature(self):
        (self.root / ".DS_Store").write_bytes(b"\x00\x00\x00\x01Bud1" + b"synthetic record\n" * 4096)
        original_open = Path.open
        raw_positions = []

        @contextmanager
        def track_open(path, *args, **kwargs):
            with original_open(path, *args, **kwargs) as handle:
                yield handle
                raw_positions.append(os.lseek(handle.fileno(), 0, os.SEEK_CUR))

        with patch.object(Path, "open", track_open):
            self.assertEqual(limits.classify(self.root, Path(".DS_Store"))[0], "BINARY")
        self.assertEqual(raw_positions, [8])

    def test_ignored_finder_metadata_is_classified_without_following_symlinks(self):
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        self.write(".gitignore", b".DS_Store\n")
        self.write(".DS_Store", b"\x00\x00\x00\x01Bud1")
        self.write("invalid/.DS_Store", b"not a metadata store")
        (self.root / "linked").mkdir()
        (self.root / "linked/.DS_Store").symlink_to(self.root / ".DS_Store")
        rows = {str(path): status for path, status, _, _ in limits.inventory(self.root)}
        self.assertEqual(rows[".DS_Store"], "BINARY")
        self.assertEqual(rows["invalid/.DS_Store"], "UNRESOLVED")
        self.assertEqual(rows["linked/.DS_Store"], "UNRESOLVED")

    def test_symlink_is_not_followed_and_deleted_file_is_reported(self):
        (self.root / "link").symlink_to("missing")
        self.assertEqual(limits.classify(self.root, Path("link"))[0], "UNRESOLVED")
        self.write("outside/file.txt", b"not part of this source tree\n")
        (self.root / "directory-link").symlink_to("outside", target_is_directory=True)
        self.assertEqual(limits.classify(self.root, Path("directory-link/file.txt"))[0], "UNRESOLVED")
        self.assertEqual(limits.classify(self.root, Path("gone"))[0], "MISSING")

    def test_population_includes_tracked_untracked_and_local_instructions(self):
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        self.write(".gitignore", b"build/\nAGENTS.md\nsecret-area/\n")
        self.write("tracked.txt", b"tracked\n")
        subprocess.run(["git", "-C", str(self.root), "add", "tracked.txt"], check=True)
        (self.root / "tracked.txt").unlink()
        self.write("new file.txt", b"new\n")
        self.write("nested/AGENTS.md", b"local instruction\n")
        self.write("nested/source.rs", b"// source\n")
        self.write("build/private.txt", b"\0")
        self.write("secret-area/opaque", b"\0")
        rows = {str(path): (status, lines) for path, status, lines, _ in limits.inventory(self.root)}
        self.assertEqual(rows["tracked.txt"], ("MISSING", None))
        self.assertEqual(rows["new file.txt"], ("TEXT", 1))
        self.assertEqual(rows["nested/AGENTS.md"], ("TEXT", 1))
        self.assertEqual(rows["build"], ("IGNORED", None))
        self.assertEqual(rows["secret-area"], ("UNRESOLVED", None))
        self.assertNotIn("build/private.txt", rows)


if __name__ == "__main__":
    unittest.main()
