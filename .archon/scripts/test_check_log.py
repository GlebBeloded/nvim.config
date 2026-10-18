"""check_log.summarize keeps a failing case's message and drops passed nested sets (run 36516373: the fix pass never saw
the stall diagnostics' phase and subprocesses, cut at 160 chars behind 24 passing `oo` lines)."""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_log  # noqa: E402

MESSAGE = "lazy surface open failed (phase: scheduled; elapsed: 10155 ms; mode: n; getchar: 0; messages: <none>; subprocesses: 20430: git status --porcelain=v2 -z"
LOG = "\n".join(
    [
        "FAIL test 317.4 s",
        "check: FAILED: test (330.0 s)",
        "===== test =====",
        *[f"tests/integration/x/test_{i}.lua | x: set {i}: oooo" for i in range(30)],
        f"FAIL in tests/integration/actions/test_plugin_ownership.lua | actions: Plugin-window mappings are action-owned: {MESSAGE}",
    ]
)


class Summarize(unittest.TestCase):
    def test_failing_case_keeps_its_message(self) -> None:
        self.assertIn("subprocesses: 20430: git status", check_log.summarize(LOG, "check.log"))

    def test_passed_nested_sets_are_noise(self) -> None:
        self.assertNotIn(": oooo", check_log.summarize(LOG, "check.log"))


if __name__ == "__main__":
    unittest.main()
