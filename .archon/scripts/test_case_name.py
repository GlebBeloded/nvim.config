"""gate.py's case_name: a case a hung worker left unrun keeps parallel.lua's note in its `FAIL in` label; the rerun's
CASE= must drop it even when the case's set is keyed by a variable (run 1202d6e0: "No test cases matched")."""

import os
import pathlib
import re
import sys
import tempfile
import unittest


def case_name(file: str, label: str, names: list[str]) -> str:
    """case_name from gate.py, loaded without running the gate (it is a script)."""
    src = pathlib.Path(__file__).with_name("gate.py").read_text()
    start = src.index("STATUS = re.compile(")
    end = src.index("def branch_cases(")
    ns: dict = {"re": re, "pathlib": pathlib, "case_names": lambda text: names}
    exec(src[start:end], ns)
    return ns["case_name"](file, label)


class CaseName(unittest.TestCase):
    def setUp(self) -> None:
        self.file = tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False).name

    def tearDown(self) -> None:
        os.unlink(self.file)

    def test_unparsed_nested_case_drops_the_not_run_note(self) -> None:
        label = "diff: Diff view opens on the current file | installs paired context folds: not run: its worker was killed after a hung case"
        self.assertEqual(case_name(self.file, label, []), "diff: Diff view opens on the current file | installs paired context folds")

    def test_hung_note_is_dropped(self) -> None:
        label = "actions: Plugin-window mappings are action-owned: hung: no progress for 300 s (waiting for input or a never-met condition?)"
        self.assertEqual(case_name(self.file, label, []), "actions: Plugin-window mappings are action-owned")

    def test_parsed_case_still_drops_an_error_message(self) -> None:
        self.assertEqual(case_name(self.file, "lsp: Ready within bound: took 9 s", ["lsp: Ready within bound"]), "lsp: Ready within bound")


if __name__ == "__main__":
    unittest.main()
