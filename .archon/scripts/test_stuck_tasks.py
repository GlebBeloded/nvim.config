"""tasks.py holds every stuck task, whichever heading level its Stuck section uses (run 69db7bfa: task 3's
`### Stuck` under its own group went unseen, so each later pass was handed the stuck task again)."""

import os
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tasks  # noqa: E402

TASKS = """## 1. Done
- [x] 1.1 a

## 2. Second
- [ ] 2.1 b

## Stuck

- Attempt 1 failed.

## 3. Third
- [ ] 3.1 c

### Stuck

- Attempt 1 failed too.

## 4. Fourth
- [ ] 4.1 d
"""


SPLIT = """## 3a. Eligible targets
- [x] 3a.1 a

## 3b. Hygiene
- [ ] 3b.1 b

## Stuck

- Attempt 1 failed.

## 3c. Close
- [ ] 3c.1 c

## 7. Render
- [ ] 7.1 d
"""


class StuckTasks(unittest.TestCase):
    def test_each_stuck_section_holds_the_task_above_it(self) -> None:
        artifacts = pathlib.Path(tempfile.mkdtemp())
        path = artifacts / "tasks.md"
        path.write_text(TASKS)
        self.assertEqual(tasks.stuck_tasks(TASKS, artifacts), ["## 2. Second", "## 3. Third"])
        self.assertTrue(tasks.next_task(path, artifacts).startswith("## 4. Fourth"))

    def test_empty_stuck_heading_holds_nothing(self) -> None:
        text = "## 1. One\n- [ ] 1.1 a\n\n## Stuck\n\n## 2. Two\n- [ ] 2.1 b\n"
        self.assertEqual(tasks.stuck_tasks(text, pathlib.Path(tempfile.mkdtemp())), [])


    def test_split_task_headings_hold_their_stuck(self):
        with tempfile.TemporaryDirectory() as root:
            path = pathlib.Path(root, "tasks.md")
            path.write_text(SPLIT)
            self.assertEqual(tasks.stuck_tasks(SPLIT, pathlib.Path(root)), ["## 3b. Hygiene"])
            self.assertTrue(tasks.next_task(path, pathlib.Path(root)).startswith("## 3c. Close"))

if __name__ == "__main__":
    unittest.main()
