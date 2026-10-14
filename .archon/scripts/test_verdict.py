"""verdict.py exhaustion (run 794e77a2: gate-red passes burned the review budget): only reviewed passes
count against MAX_ATTEMPTS; MAX_PASSES still bounds every pass."""

import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().with_name("verdict.py")
GREEN = {"GREEN": "true", "SPEC_OK": "true", "TASKS_DONE": "true", "CRITICAL": "0", "APPROVE": "false"}


class Verdict(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = tempfile.mkdtemp()
        self.artifacts = tempfile.mkdtemp()

    def run_pass(self, **inputs: str) -> dict:
        env = {**os.environ, "ARTIFACTS_DIR": self.artifacts, "INPUTS_CHANGE": ""}
        env.update({"INPUTS_" + k: v for k, v in inputs.items()})
        out = subprocess.run([sys.executable, str(SCRIPT)], cwd=self.repo, env=env, capture_output=True, text=True, check=True)
        return json.loads(out.stdout)

    def test_gate_red_passes_burn_no_attempt(self) -> None:
        for attempt in range(1, 4):
            out = self.run_pass(**{**GREEN, "GREEN": "false", "ATTEMPT": str(attempt)})
            self.assertFalse(out["done"], out)
        self.assertEqual(out["reviews"], 0)
        for _ in range(2):
            self.assertFalse(self.run_pass(**GREEN, ATTEMPT="4")["done"])  # passes 4, 5: reviews 1, 2

    def test_reviewed_rejections_exhaust(self) -> None:
        outs = [self.run_pass(**GREEN, ATTEMPT=str(n)) for n in range(1, 4)]
        self.assertEqual([o["exhausted"] for o in outs], [False, False, True])

    def test_max_passes_bounds_red_passes(self) -> None:
        outs = [self.run_pass(**{**GREEN, "GREEN": "false", "ATTEMPT": str(n)}) for n in range(1, 7)]
        self.assertEqual([o["exhausted"] for o in outs], [False] * 5 + [True])


if __name__ == "__main__":
    unittest.main()
