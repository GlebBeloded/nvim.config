"""tasks.md helpers shared by the gate, the context pack and the per-task loop. Only real checkbox
list items count: prose such as "checkbox (`- [ ]`) syntax" in a plan header is not a task.

As a script: exits 0 when the per-task loop is done (no unchecked task, a `## Blocked` section, or
MAX_PASSES implement passes counted in $ARTIFACTS_DIR/task-passes), 1 while a task is left.
"""

import os
import pathlib
import re
import sys

UNCHECKED = re.compile(r"^\s*[-*] \[ \] ", re.MULTILINE)
TASK_HEADING = re.compile(r"^#{2,4} .*$", re.MULTILINE)
MAX_PASSES = 30


def unchecked(text: str) -> int:
    return len(UNCHECKED.findall(text))


def next_task(tasks: pathlib.Path) -> str:
    """The heading and body of the first task section that still has an unchecked item."""
    if not tasks.exists():
        return ""
    text = tasks.read_text()
    starts = [m.start() for m in TASK_HEADING.finditer(text)] + [len(text)]
    for start, end in zip(starts, starts[1:]):
        if UNCHECKED.search(text[start:end]):
            return text[start:end].strip()
    match = UNCHECKED.search(text)
    return text[match.start() : match.start() + 2000].strip() if match else ""


def loop_done(tasks: pathlib.Path, artifacts: pathlib.Path) -> bool:
    counter = artifacts / "task-passes"
    passes = int(counter.read_text()) + 1 if counter.exists() else 1
    counter.write_text(str(passes))
    text = tasks.read_text() if tasks.exists() else ""
    return unchecked(text) == 0 or "## Blocked" in text or passes >= MAX_PASSES


if __name__ == "__main__":
    artifacts = pathlib.Path(os.environ.get("ARTIFACTS_DIR", "."))
    saved = artifacts / "change"  # written by context_pack.py: until_bash gets no INPUTS_* env
    change = os.environ.get("INPUTS_CHANGE") or (sys.argv[1] if len(sys.argv) > 1 else "")
    change = change or (saved.read_text().strip() if saved.exists() else "")
    if not (pathlib.Path("openspec/changes") / change / "tasks.md").exists():
        print(f"tasks.py: no tasks.md for change {change!r}", file=sys.stderr)
    sys.exit(0 if loop_done(pathlib.Path("openspec/changes") / change / "tasks.md", artifacts) else 1)
