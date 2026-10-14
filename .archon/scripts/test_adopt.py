"""adopt.py on a branch that fixed the shortcut table (run 794e77a2: the revert re-broke `chain`): edits to a
main spec's data sections are kept, edits to its Requirements are still reverted."""

import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().with_name("adopt.py")
SPEC = "openspec/specs/shortcuts/spec.md"
BASE = "# shortcuts\n\n## Requirements\n\n### Requirement: R\nold rule\n\n## Shortcut table\n\n| Cmd+Shift+F | `<Cmd>Telescope live_grep<CR>` |\n"


class Adopt(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = tempfile.mkdtemp()
        env = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}
        self.env = {**os.environ, **env, "BASE_BRANCH": "auto"}
        self.git("init", "-q", "-b", "auto")
        self.commit({SPEC: BASE}, "base")
        self.git("checkout", "-q", "-b", "old")

    def git(self, *args: str) -> str:
        return subprocess.run(["git", *args], cwd=self.repo, env=self.env, check=True, capture_output=True, text=True).stdout

    def commit(self, files: dict[str, str], msg: str) -> None:
        for path, text in files.items():
            (pathlib.Path(self.repo) / path).parent.mkdir(parents=True, exist_ok=True)
            (pathlib.Path(self.repo) / path).write_text(text)
        self.git("add", "-A")
        self.git("commit", "-q", "-m", msg)

    def adopt(self) -> dict:
        self.git("checkout", "-q", "-b", "run", "auto")
        env = {**self.env, "INPUTS_ADOPT": "old"}
        out = subprocess.run([sys.executable, str(SCRIPT)], cwd=self.repo, env=env, check=True, capture_output=True, text=True)
        self.assertEqual(self.git("status", "--porcelain"), "")
        return json.loads(out.stdout)

    def test_table_fix_survives_adopt(self) -> None:
        table = BASE.replace("`<Cmd>Telescope live_grep<CR>`", 'fn `require("gleb.picker").grep_live`')
        self.commit({SPEC: table}, "fix table")
        out = self.adopt()
        self.assertNotIn("reverted", out["summary"])
        self.assertEqual((pathlib.Path(self.repo) / SPEC).read_text(), table)

    def test_requirement_edit_reverted_table_kept(self) -> None:
        both = BASE.replace("old rule", "weaker rule").replace("live_grep", "grep_live")
        self.commit({SPEC: both}, "edit both")
        out = self.adopt()
        self.assertIn(f"reverted its main spec edits ({SPEC})", out["summary"])
        self.assertEqual((pathlib.Path(self.repo) / SPEC).read_text(), BASE.replace("live_grep", "grep_live"))


if __name__ == "__main__":
    unittest.main()
