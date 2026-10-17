"""spec_ready.py skips the AI spec step only for a folder the user finished (run 9e24df4b: the spec step
rewrote references-test-scope's concrete paths into vague scenarios although the folder passed the gate)."""

import os
import pathlib
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spec_ready  # noqa: E402

GREEN = {"ok": True, "log": ""}


class SpecReady(unittest.TestCase):
    def check(self, tasks: str | None) -> dict:
        with tempfile.TemporaryDirectory() as root:
            folder = pathlib.Path(root, "c")
            folder.mkdir()
            if tasks is not None:
                (folder / "tasks.md").write_text(tasks)
            with mock.patch.dict(os.environ, {"LOOP_CHANGES_DIR": root}), mock.patch.object(spec_ready, "gate", return_value=GREEN):
                return spec_ready.ready("c")

    def test_finished_folder_passing_the_gate_is_ready(self):
        self.assertEqual(self.check("## 1. A\n- [ ] 1.1 write it\n"), GREEN)

    def test_missing_tasks_is_not_ready(self):
        self.assertFalse(self.check(None)["ok"])
        self.assertFalse(self.check("## 1. A\n")["ok"])

    def test_unsettled_blocked_section_is_not_ready(self):
        self.assertFalse(self.check("## 1. A\n- [ ] 1.1 x\n\n## Blocked\n- which?\n")["ok"])
        self.assertFalse(self.check("## 1. A\n- [ ] 1.1 x\n\n## Unblocked\n- this\n")["ok"])

    def test_auditor_decision_is_not_ready(self):
        with tempfile.TemporaryDirectory() as root:
            pathlib.Path(root, "c").mkdir()
            pathlib.Path(root, "c", "tasks.md").write_text("- [ ] 1.1 x\n")
            pathlib.Path(root, "c", "proposal.md").write_text("## Why\nx\n\n## Decision (auditor, 2026-10-17)\n- split task 2\n")
            with mock.patch.dict(os.environ, {"LOOP_CHANGES_DIR": root}), mock.patch.object(spec_ready, "gate", return_value=GREEN):
                self.assertFalse(spec_ready.ready("c")["ok"])

    def test_red_gate_is_not_ready(self):
        with tempfile.TemporaryDirectory() as root:
            pathlib.Path(root, "c").mkdir()
            pathlib.Path(root, "c", "tasks.md").write_text("- [ ] 1.1 x\n")
            red = {"ok": False, "log": "spec_trial.py failed"}
            with mock.patch.dict(os.environ, {"LOOP_CHANGES_DIR": root}), mock.patch.object(spec_ready, "gate", return_value=red):
                self.assertEqual(spec_ready.ready("c"), red)


if __name__ == "__main__":
    unittest.main()
