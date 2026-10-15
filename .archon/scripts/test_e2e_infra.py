"""gate.py's e2e_infra: an e2e section where no case ran and only sandbox lines appear is the host's
failure even without a known keyword (run 8ce36755), and any real case keeps it the change's."""

import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

WAIT = "sandbox: nvim-e2e has a lume run process while Lume reports it ; waiting for it"


def classify(body: list[str]) -> str:
    """e2e_infra from gate.py, loaded without running the gate (it is a script)."""
    src = pathlib.Path(__file__).with_name("gate.py").read_text()
    start = src.index("INFRA_LINE = ")
    end = src.index("def case_name(")
    ns: dict = {"re": __import__("re"), "failing_cases": lambda lines: [l for l in lines if l.startswith("FAIL in ")]}
    exec(src[start:end], ns)
    return ns["e2e_infra"](body)


class E2eInfra(unittest.TestCase):
    def test_sandbox_only_failure_is_infra(self) -> None:
        self.assertEqual(classify([WAIT, "make[2]: *** [e2e] Error 1"]), WAIT)

    def test_failing_case_is_not_infra(self) -> None:
        self.assertEqual(classify([WAIT, "FAIL in tests/e2e/x.lua | x: y", "make[2]: *** [e2e] Error 1"]), "")


if __name__ == "__main__":
    unittest.main()
