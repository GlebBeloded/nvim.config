"""Scenarios of an OpenSpec change and which of them no test names. As a script: prints the untested
"<capability>: <title>" names of change $1, one per line (exit 1 when any)."""

import pathlib
import re
import sys

SCENARIO = re.compile(r"^#### Scenario:\s*(.+?)\s*$")


def scenario_blocks(text: str) -> dict[str, str]:
    """title -> scenario body (its WHEN/THEN lines), skipping a delta's REMOVED section."""
    blocks, title, removed = {}, None, False
    for line in text.splitlines():
        if line.startswith("## "):
            removed, title = line.startswith("## REMOVED"), None
            continue
        m = SCENARIO.match(line)
        if m:
            title = None if removed else m.group(1)
            if title:
                blocks[title] = ""
        elif title and (line.startswith("### ") or line.startswith("#### ")):
            title = None
        elif title:
            blocks[title] += line.strip() + "\n"
    return {t: b.strip() for t, b in blocks.items()}


def change_scenarios(change_dir: pathlib.Path) -> list[str]:
    """"<capability>: <title>" of every scenario the change adds or whose text it changes. A MODIFIED
    requirement repeats its unchanged scenarios; those keep whatever coverage they had."""
    names = []
    for spec in sorted(change_dir.glob("specs/*/spec.md")):
        main = pathlib.Path("openspec/specs") / spec.parent.name / "spec.md"
        before = scenario_blocks(main.read_text()) if main.exists() else {}
        for title, body in scenario_blocks(spec.read_text()).items():
            if before.get(title) != body:
                names.append(f"{spec.parent.name}: {title}")
    return names


TASK_SCENARIO = re.compile(r"`([a-z0-9-]+: [^`]+)`")


def task_scenarios(change_dir: pathlib.Path) -> list[str]:
    """"<capability>: <title>" names on tasks.md `Scenarios:` lines (covers a fix whose spec needs no delta)."""
    tasks = change_dir / "tasks.md"
    if not tasks.exists():
        return []
    lines = [l for l in tasks.read_text().splitlines() if "scenario" in l.lower()]
    return [n for l in lines for n in TASK_SCENARIO.findall(l)]


def covered(change_dir: pathlib.Path) -> list[str]:
    """Every scenario the change is responsible for: added or changed in its delta, or named by its tasks."""
    return list(dict.fromkeys(change_scenarios(change_dir) + task_scenarios(change_dir)))


def unknown(change_dir: pathlib.Path) -> list[str]:
    """Scenario names on tasks.md `Scenarios:` lines that no spec defines (main specs or this change's delta)."""
    known = set()
    for spec in list(pathlib.Path("openspec/specs").glob("*/spec.md")) + list(change_dir.glob("specs/*/spec.md")):
        known |= {f"{spec.parent.name}: {t}" for t in scenario_blocks(spec.read_text())}
    return [n for n in task_scenarios(change_dir) if n not in known]


def untested(names: list[str]) -> list[str]:
    """Scenarios no test case names exactly (replaces the verify agent's traceability check)."""
    text = "\n".join(p.read_text(errors="replace") for p in pathlib.Path("tests").rglob("test_*.lua"))
    return [n for n in names if f'"{n}"' not in text]


if __name__ == "__main__":
    if sys.argv[1] == "--unknown":  # spec-gate: tasks may only name scenarios that exist
        bad = unknown(pathlib.Path("openspec/changes") / sys.argv[2])
        if bad:
            print("tasks.md names scenarios no spec defines:\n" + "\n".join("- " + n for n in bad))
        sys.exit(1 if bad else 0)
    missing = untested(covered(pathlib.Path("openspec/changes") / sys.argv[1]))
    print("\n".join(missing))
    sys.exit(1 if missing else 0)
