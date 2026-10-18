"""spec_ready.py skips the AI spec step only for a folder the user finished (run 9e24df4b: the spec step
rewrote references-test-scope's concrete paths into vague scenarios although the folder passed the gate)."""

import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spec_ready  # noqa: E402
from spec_gate import UNFINISHED  # noqa: E402

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


class UnfinishedSpecPass(unittest.TestCase):
    """Run d2fd2377: the Mac slept mid spec step, Archon's idle timeout counted the half-done pass as done."""

    def test_marker_is_written_when_the_spec_step_runs_and_removed_when_ready(self):
        with tempfile.TemporaryDirectory() as root:
            artifacts = pathlib.Path(root)
            spec_ready.mark({"ok": False, "log": "no tasks.md tasks"}, artifacts)
            self.assertTrue((artifacts / spec_ready.PENDING).exists())
            spec_ready.mark(GREEN, artifacts)
            self.assertFalse((artifacts / spec_ready.PENDING).exists())

    def test_gate_is_red_while_the_marker_is_left(self):
        scripts = os.path.dirname(os.path.abspath(__file__))
        with tempfile.TemporaryDirectory() as root:
            pathlib.Path(root, spec_ready.PENDING).write_text("x\n")
            env = dict(os.environ, ARTIFACTS_DIR=root, INPUTS_CHANGE="c", INPUTS_FAILED_LOG="")
            proc = subprocess.run([sys.executable, os.path.join(scripts, "spec_gate.py")], env=env, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(json.loads(proc.stdout), {"ok": False, "log": UNFINISHED})


if __name__ == "__main__":
    unittest.main()
