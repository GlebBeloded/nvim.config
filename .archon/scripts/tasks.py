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
SMALL = 4  # changes with at most this many tasks are implemented in one session


def task_sections(text: str) -> list[str]:
    """Each task heading's section that holds at least one checkbox."""
    starts = [m.start() for m in TASK_HEADING.finditer(text)] + [len(text)]
    sections = [text[a:b].strip() for a, b in zip(starts, starts[1:])]
    return [sec for sec in sections if re.search(r"^\s*[-*] \[[ x]\] ", sec, re.MULTILINE)]


# "Run `make check`" items are the gate's job (agents never run it): they do not hold the task loop,
# and gate.py ticks them once the check is green.
GATE_ITEM = re.compile(r"^\s*[-*] \[ \] .*`make (check|quick)\b[^`]*`", re.MULTILINE)


def unchecked(text: str) -> int:
    return len(UNCHECKED.findall(text)) - len(GATE_ITEM.findall(text))


def tick_gate_items(text: str) -> str:
    return GATE_ITEM.sub(lambda m: m.group(0).replace("[ ]", "[x]", 1), text)


def next_task(tasks: pathlib.Path) -> str:
    """The first task section with an unchecked item; for a small change (<= SMALL tasks) every such
    section, so one implement session does them all."""
    if not tasks.exists():
        return ""
    text = tasks.read_text()
    sections = task_sections(text)
    if 0 < len(sections) <= SMALL:
        return "\n\n".join(sec for sec in sections if unchecked(sec))
    starts = [m.start() for m in TASK_HEADING.finditer(text)] + [len(text)]
    for start, end in zip(starts, starts[1:]):
        section = text[start:end]
        if len(UNCHECKED.findall(section)) > len(GATE_ITEM.findall(section)):
            return section.strip()
    match = UNCHECKED.search(text)
    return text[match.start() : match.start() + 2000].strip() if match else ""


def loop_done(tasks: pathlib.Path, artifacts: pathlib.Path) -> bool:
    counter = artifacts / "task-passes"
    passes = int(counter.read_text()) + 1 if counter.exists() else 1
    counter.write_text(str(passes))
    text = tasks.read_text() if tasks.exists() else ""
    return unchecked(text) == 0 or "## Blocked" in text or passes >= MAX_PASSES


def plan_needed(tasks: pathlib.Path) -> bool:
    """The spec step usually writes tasks.md already; plan only when it has no task yet."""
    return not tasks.exists() or not task_sections(tasks.read_text())


if __name__ == "__main__":
    if sys.argv[1:2] == ["--plan-needed"]:
        import json

        change = os.environ.get("INPUTS_CHANGE", "")
        print(json.dumps({"needed": plan_needed(pathlib.Path("openspec/changes") / change / "tasks.md")}))
        sys.exit(0)
    artifacts = pathlib.Path(os.environ.get("ARTIFACTS_DIR", "."))
    saved = artifacts / "change"  # written by context_pack.py: until_bash gets no INPUTS_* env
    change = os.environ.get("INPUTS_CHANGE") or (sys.argv[1] if len(sys.argv) > 1 else "")
    change = change or (saved.read_text().strip() if saved.exists() else "")
    if not (pathlib.Path("openspec/changes") / change / "tasks.md").exists():
        print(f"tasks.py: no tasks.md for change {change!r}", file=sys.stderr)
    sys.exit(0 if loop_done(pathlib.Path("openspec/changes") / change / "tasks.md", artifacts) else 1)
