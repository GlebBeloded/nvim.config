"""context_pack.py names design.md's `## Renders` by path instead of inlining it (run 499b0b85: 27 KB
of a 77 KB pack); the agent reads it when the task draws."""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from context_pack import current_design  # noqa: E402

DESIGN = "## Context\nwhy\n\n## Renders\n### Proposed A\n```\nbox\n```\n\n## Decisions\n1. keep\n"


class Renders(unittest.TestCase):
    def test_renders_are_named_by_path_not_inlined(self) -> None:
        out = current_design(DESIGN, "openspec/changes/c/design.md")
        self.assertNotIn("Proposed A", out)
        self.assertIn("## Decisions", out)
        self.assertIn("read openspec/changes/c/design.md when the task draws", out)

    def test_design_without_renders_is_unchanged(self) -> None:
        self.assertEqual(current_design("## Context\nwhy\n", "d.md"), "## Context\nwhy\n")


if __name__ == "__main__":
    unittest.main()
