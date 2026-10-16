"""sync_base.py merges a moved base into the run branch before the gate, only when clean."""

import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sync_base  # noqa: E402


class SyncBase(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = tempfile.mkdtemp()
        self.cwd = os.getcwd()
        os.chdir(self.repo)
        os.environ.update({"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"})
        self.git("init", "-q", "-b", "auto")
        self.commit("a.txt", "base\n")
        self.git("checkout", "-q", "-b", "run")
        self.commit("b.txt", "branch\n")
        self.git("checkout", "-q", "auto")
        self.commit("c.txt", "base moved\n")
        self.git("checkout", "-q", "run")

    def tearDown(self) -> None:
        os.chdir(self.cwd)

    def git(self, *args: str) -> str:
        return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout

    def commit(self, path: str, text: str) -> None:
        pathlib.Path(path).write_text(text)
        self.git("add", path)
        self.git("commit", "-qm", path)

    def test_clean_branch_gets_the_moved_base(self):
        self.assertEqual(sync_base.sync(), "sync: merged auto")
        self.assertTrue(pathlib.Path("c.txt").exists())
        self.assertEqual(sync_base.sync(), "")

    def test_tracked_edits_skip_the_merge(self):
        pathlib.Path("b.txt").write_text("edited\n")
        self.assertIn("tracked edits", sync_base.sync())
        self.assertFalse(pathlib.Path("c.txt").exists())

    def test_conflict_is_aborted(self):
        self.git("checkout", "-q", "auto")
        self.commit("b.txt", "base side\n")
        self.git("checkout", "-q", "run")
        self.assertIn("conflicts", sync_base.sync())
        self.assertEqual(self.git("status", "--porcelain"), "")
        self.assertFalse(pathlib.Path("c.txt").exists())


if __name__ == "__main__":
    unittest.main()
