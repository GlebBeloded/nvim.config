"""planned_removals counts the main-spec scenarios of a requirement an OpenSpec REMOVED block names by title only
(run 3f6b4fd0: self-check flagged 6 spec-removed keymaps cases as lost on every pass)."""

import os
import pathlib
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import integrity  # noqa: E402

MAIN = """# keymaps

## Requirements

### Requirement: Differ entry point
Alt-g SHALL open Differ.

#### Scenario: Alt-g opens Differ
- **WHEN** x
- **THEN** y

### Requirement: Kept
Kept SHALL hold.

#### Scenario: Kept case
- **WHEN** x
- **THEN** y
"""

DELTA = """## REMOVED Requirements

### Requirement: Differ entry point
**Reason**: differ.nvim is removed.
**Migration**: "Alt-g opens Differ" → `keymaps: Alt-g opens the changes review`.
"""


class PlannedRemovals(unittest.TestCase):
    def test_title_only_removed_requirement_counts_its_main_spec_scenarios(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            for path, text in {"openspec/specs/keymaps/spec.md": MAIN, "openspec/changes/c/specs/keymaps/spec.md": DELTA}.items():
                target = pathlib.Path(root, path)
                target.parent.mkdir(parents=True)
                target.write_text(text)
            cwd = os.getcwd()
            os.chdir(root)
            try:
                with mock.patch.dict(os.environ, {"LOOP_CHANGES_DIR": ""}):
                    found = integrity.planned_removals()
            finally:
                os.chdir(cwd)
        self.assertEqual(found, {"keymaps: Alt-g opens Differ"})


if __name__ == "__main__":
    unittest.main()
