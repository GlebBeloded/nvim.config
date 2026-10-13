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


def untested(names: list[str]) -> list[str]:
    """Scenarios no test case names exactly (replaces the verify agent's traceability check)."""
    text = "\n".join(p.read_text(errors="replace") for p in pathlib.Path("tests").rglob("test_*.lua"))
    return [n for n in names if f'"{n}"' not in text]


if __name__ == "__main__":
    missing = untested(change_scenarios(pathlib.Path("openspec/changes") / sys.argv[1]))
    print("\n".join(missing))
    sys.exit(1 if missing else 0)
