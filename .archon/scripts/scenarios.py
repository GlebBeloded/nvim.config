"""Scenarios of an OpenSpec change and which of them no test names. As a script: prints the untested
"<capability>: <title>" names of change $1, one per line (exit 1 when any)."""

import pathlib
import re
import sys

SCENARIO = re.compile(r"^#### Scenario:\s*(.+?)\s*$")


def change_scenarios(change_dir: pathlib.Path) -> list[str]:
    """"<capability>: <title>" of every scenario the change adds or modifies (not REMOVED)."""
    names = []
    for spec in sorted(change_dir.glob("specs/*/spec.md")):
        removed = False
        for line in spec.read_text().splitlines():
            if line.startswith("## "):
                removed = line.startswith("## REMOVED")
            m = SCENARIO.match(line)
            if m and not removed:
                names.append(f"{spec.parent.name}: {m.group(1)}")
    return names


def untested(names: list[str]) -> list[str]:
    """Scenarios no test case names exactly (replaces the verify agent's traceability check)."""
    text = "\n".join(p.read_text(errors="replace") for p in pathlib.Path("tests").rglob("test_*.lua"))
    return [n for n in names if f'"{n}"' not in text]


if __name__ == "__main__":
    missing = untested(change_scenarios(pathlib.Path("openspec/changes") / sys.argv[1]))
    print("\n".join(missing))
    sys.exit(1 if missing else 0)
