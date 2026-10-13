"""`## Blocked` sections: a step that cannot go on without the user writes one in the change's
proposal.md or tasks.md. Then no agent works the change any more: work-queue goes straight to the
blocked gate (before spec), verdict.py ends the build loop and escalation.py asks, quoting it.

As a script (work-queue `blocked` node): prints {blocked, text} for INPUTS_CHANGE under
LOOP_CHANGES_DIR (fixtures) or openspec/changes, and writes escalation.md when blocked.
"""

import json
import os
import pathlib
import re

SECTION = re.compile(r"^## Blocked\b.*?(?=^## |\Z)", re.MULTILINE | re.DOTALL)
QUOTE_CHARS = 2000


def changes_dir() -> pathlib.Path:
    return pathlib.Path(os.environ.get("LOOP_CHANGES_DIR") or "openspec/changes")


def blocked_text(change: str) -> str:
    """Every `## Blocked` section of the change's proposal.md and tasks.md, each prefixed with its file."""
    folder = changes_dir() / change
    found = []
    for name in ("proposal.md", "tasks.md"):
        path = folder / name
        if change and path.is_file():
            found += [f"{name}: {m.group(0).strip()}" for m in SECTION.finditer(path.read_text())]
    return "\n\n".join(found)[:QUOTE_CHARS]


def main() -> None:
    change = os.environ.get("INPUTS_CHANGE", "")
    text = blocked_text(change)
    if text:
        artifacts = pathlib.Path(os.environ.get("ARTIFACTS_DIR", "."))
        (artifacts / "escalation.md").write_text(f"# Judge: ask\n\n- blocked: {text}\n")
    print(json.dumps({"blocked": bool(text), "text": text}))


if __name__ == "__main__":
    main()
