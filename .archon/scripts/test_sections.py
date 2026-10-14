"""An empty `## Stuck` / `## Blocked` heading counts as absent (run 9c94cd75, picker-ui: the spec step left an
empty `## Stuck`, the pack recorded group 1 as stuck and implement skipped the foundation group), and the pack
lists .tests/deps plugins (mini.nvim lives only there).

Run: python3 -m unittest discover -s .archon/scripts -p 'test_*.py'
"""

import os
import pathlib
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blocked  # noqa: E402
import context_pack  # noqa: E402
import tasks  # noqa: E402

# tasks.md of run 9c94cd75 (picker-ui), trimmed to two groups; the tail is verbatim
PICKER_UI = """\
## 1. Build the shared picker frame
Scenarios: `picker: Wide picker matches reference screenshot`
- [ ] 1.1 Write the test `picker: Wide picker matches reference screenshot` in tests/screen/picker/test_frame.lua and see it fail
- [ ] 1.2 Add the mini.pick setup in `lua/gleb/picker/`
- [ ] 1.3 Run `make test FILE=tests/screen/picker/test_frame.lua CASE="Wide picker matches reference screenshot"` and see it pass

## 2. Render picker rows
Scenarios: `picker: Rows show fields`
- [ ] 2.1 Write the test `picker: Rows show fields` in tests/unit/picker/test_rows.lua and see it fail

## Stuck

## Agent decisions

- Row visibility uses named `show_*` options.
"""


class EmptySections(unittest.TestCase):
    def test_empty_stuck_heading_is_absent(self):
        self.assertEqual(blocked.STUCK.findall(PICKER_UI), [])
        with tempfile.TemporaryDirectory() as tmp:
            artifacts = pathlib.Path(tmp)
            self.assertEqual(tasks.stuck_tasks(PICKER_UI, artifacts), [])
            self.assertFalse((artifacts / tasks.STUCK_TASKS).exists())
            path = artifacts / "tasks.md"
            path.write_text(PICKER_UI)
            self.assertTrue(tasks.next_task(path, artifacts).startswith("## 1. Build the shared picker frame"))
            self.assertFalse(tasks.loop_done(path, artifacts))

    def test_empty_stuck_and_blocked_quote_nothing(self):
        with tempfile.TemporaryDirectory() as tmp:
            change = pathlib.Path(tmp) / "picker-ui"
            change.mkdir()
            (change / "tasks.md").write_text(PICKER_UI.replace("## Stuck\n", "## Blocked\n\n## Stuck\n"))
            with mock.patch.dict(os.environ, {"LOOP_CHANGES_DIR": tmp}):
                self.assertEqual(blocked.stuck_text("picker-ui"), "")
                self.assertEqual(blocked.blocked_text("picker-ui"), "")
            self.assertFalse(blocked.blocks((change / "tasks.md").read_text()))

    def test_filled_sections_still_count(self):
        filled = PICKER_UI.replace("## Stuck\n", "## Stuck\n\n1.3 still red: probe output\n")
        self.assertEqual(len(blocked.STUCK.findall(filled)), 1)
        self.assertTrue(blocked.blocks("## Blocked\n\n- choose A or B (recommend A)\n"))
        self.assertTrue(blocked.blocks("## Blocked\n### 1. task\n- choose A or B\n"))
        self.assertFalse(blocked.blocks("## Blocked"))


class TestDeps(unittest.TestCase):
    def test_lists_mini_nvim_and_named_modules(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            for mod in ("pick", "extra", "files"):
                (root / ".tests/deps/mini.nvim/lua/mini").mkdir(parents=True, exist_ok=True)
                (root / f".tests/deps/mini.nvim/lua/mini/{mod}.lua").write_text("")
            (root / ".tests/deps/lazy.nvim").mkdir()
            change = root / "change"
            change.mkdir()
            (change / "proposal.md").write_text("Use mini.pick with mini.extra; keep the minimal init.\n")
            cwd = os.getcwd()
            os.chdir(root)
            try:
                out = context_pack.plugin_sources(change)
            finally:
                os.chdir(cwd)
            self.assertIn("mini.nvim (test dependency): ", out)
            self.assertIn("lua/mini/extra.lua, lua/mini/pick.lua", out)
            self.assertNotIn("files.lua", out)
            self.assertNotIn("lazy.nvim", out)


class Conventions(unittest.TestCase):
    def test_inlines_conventions_and_helper_index(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "docs").mkdir()
            (root / "tests").mkdir()
            (root / "docs/architecture.md").write_text("# A\n\n## Map\nx\n\n## Conventions\n- one module per file\n")
            (root / "tests/helpers.lua").write_text("--- New child.\n---@return table\nfunction M.new_child()\nend\n")
            cwd = os.getcwd()
            os.chdir(root)
            try:
                out = context_pack.conventions()
            finally:
                os.chdir(cwd)
            self.assertIn("- one module per file", out)
            self.assertNotIn("## Map", out)
            self.assertIn("- M.new_child()  (line 3): New child.", out)


if __name__ == "__main__":
    unittest.main()
