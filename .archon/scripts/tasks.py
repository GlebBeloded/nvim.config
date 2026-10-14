"""tasks.md helpers shared by the gate, the context pack and the per-task loop. Only real checkbox
list items count: prose such as "checkbox (`- [ ]`) syntax" in a plan header is not a task.

`--adopted-state` prints {archived, tasks_done, visible_ui} for work-queue after adopt: no change folder
means an adopted branch archived it; every task ticked means the spec step has nothing left (visible
UI is then read from design.md: true only when it holds a render section, as visible-UI designs do). LOOP_CHANGES_DIR overrides
openspec/changes (fixtures).

As a script: exits 0 when the per-task loop is done (no unchecked task, a blocking `## Blocked` section, or
MAX_PASSES implement passes counted in $ARTIFACTS_DIR/task-passes), 1 while a task is left.
"""

import os
import pathlib
import re
import sys

from blocked import blocks

UNCHECKED = re.compile(r"^\s*[-*] \[ \] ", re.MULTILINE)
TASK_HEADING = re.compile(r"^#{2,4} .*$", re.MULTILINE)
MAX_PASSES = 30
SMALL = 4  # changes with at most this many tasks are implemented in one session


def has_render(design) -> bool:
    """A visible-UI design.md holds a `Current render` / `Proposed render` section; a technical one does not."""
    return design.is_file() and re.search(r"(?mi)^#+ .*\brender\b", design.read_text()) is not None


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
    return unchecked(text) == 0 or blocks(text) or passes >= MAX_PASSES


def plan_needed(tasks: pathlib.Path) -> bool:
    """The spec step usually writes tasks.md already; plan only when it has no task yet."""
    return not tasks.exists() or not task_sections(tasks.read_text())


def spec_work_left(folder: pathlib.Path) -> bool:
    """A fully ticked adopted change still needs the spec step when its proposal carries a rejected run's
    reasons (new tasks to plan) or a main-spec scenario it pins has no delta yet."""
    proposal = folder / "proposal.md"
    if proposal.is_file() and re.search(r"(?m)^## Rejected run\b", proposal.read_text()):
        return True
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from pinned import pinned

    return bool(pinned(folder.name))


def adopted_state(folder: pathlib.Path) -> dict[str, bool]:
    tasks = folder / "tasks.md"
    done = tasks.exists() and bool(task_sections(tasks.read_text())) and unchecked(tasks.read_text()) == 0
    if done and spec_work_left(folder):
        done = False
    return {"archived": not folder.is_dir(), "tasks_done": done, "visible_ui": has_render(folder / "design.md")}


if __name__ == "__main__":
    if sys.argv[1:2] == ["--adopted-state"]:
        import json

        changes = pathlib.Path(os.environ.get("LOOP_CHANGES_DIR") or "openspec/changes")
        print(json.dumps(adopted_state(changes / os.environ.get("INPUTS_CHANGE", ""))))
        sys.exit(0)
    if sys.argv[1:2] == ["--plan-needed"]:
        import json

        change = os.environ.get("INPUTS_CHANGE", "")
        folder = pathlib.Path("openspec/changes") / change
        has = folder.is_dir()
        print(json.dumps({"needed": has and plan_needed(folder / "tasks.md"), "has_change": has}))
        sys.exit(0)
    artifacts = pathlib.Path(os.environ.get("ARTIFACTS_DIR", "."))
    saved = artifacts / "change"  # written by context_pack.py: until_bash gets no INPUTS_* env
    change = os.environ.get("INPUTS_CHANGE") or (sys.argv[1] if len(sys.argv) > 1 else "")
    change = change or (saved.read_text().strip() if saved.exists() else "")
    if not (pathlib.Path("openspec/changes") / change / "tasks.md").exists():
        print(f"tasks.py: no tasks.md for change {change!r}", file=sys.stderr)
    sys.exit(0 if loop_done(pathlib.Path("openspec/changes") / change / "tasks.md", artifacts) else 1)
