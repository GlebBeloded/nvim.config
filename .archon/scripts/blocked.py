"""`## Blocked` sections: a step that cannot go on without the user writes one in the change's
proposal.md or tasks.md. Then no agent works the change any more: work-queue goes straight to the
blocked gate (before spec), verdict.py ends the build loop and escalation.py asks, quoting it.
A section whose every item starts with `loop:` is about loop tooling, not the change: it blocks
nothing and escalation.py lists its items, with $ARTIFACTS_DIR/loop-notes.md lines, as notes.

As a script (work-queue `blocked` node): prints {blocked, text} for INPUTS_CHANGE under
LOOP_CHANGES_DIR (fixtures) or openspec/changes, and writes escalation.md when blocked.
"""

import json
import os
import pathlib
import re
import subprocess
import time

SECTION = re.compile(r"^## Blocked\b.*?(?=^## |\Z)", re.MULTILINE | re.DOTALL)
LOOP_ITEM = re.compile(r"^(?:[-*]\s+)?(loop:.*)$", re.IGNORECASE)
QUOTE_CHARS = 2000


def changes_dir() -> pathlib.Path:
    return pathlib.Path(os.environ.get("LOOP_CHANGES_DIR") or "openspec/changes")


def git_time(path: pathlib.Path, *args: str) -> float | None:
    """Commit time of the last commit touching `path` (narrowed by `args`); now when it has uncommitted edits."""
    def git(*cmd: str) -> str:
        proc = subprocess.run(["git", *cmd], cwd=path.parent, capture_output=True, text=True)
        return proc.stdout.strip() if proc.returncode == 0 else ""
    if git("status", "--porcelain", "--", path.name):
        return time.time()
    out = git("log", "-1", "--format=%ct", *args, "--", path.name)
    return float(out) if out else None


def decided_after(folder: pathlib.Path, path: pathlib.Path) -> bool:
    """A user `## Decision` committed to proposal.md after `path` was last changed resolves its Blocked section."""
    proposal = folder / "proposal.md"
    decided = git_time(proposal, "-G", "^## Decision .user") if proposal.is_file() else None
    blocked = git_time(path)
    return decided is not None and blocked is not None and decided > blocked


def items(section: str) -> list[str]:
    """The non-empty lines of a `## Blocked` section after its heading."""
    return [line.strip() for line in section.splitlines()[1:] if line.strip()]


def loop_items(section: str) -> list[str]:
    """The `loop: …` items of a section that holds nothing else, else []."""
    found = [LOOP_ITEM.match(item) for item in items(section)]
    return [m.group(1) for m in found] if found and all(found) else []


def blocks(text: str) -> bool:
    """Whether `text` holds a `## Blocked` section that is not only about loop tooling."""
    return any(not loop_items(m.group(0)) for m in SECTION.finditer(text))


def sections(change: str) -> list[tuple[str, str]]:
    """(file, section) for every `## Blocked` section of the change's proposal.md and tasks.md, except
    one older than a later user `## Decision` (it is resolved; the spec step removes it)."""
    folder = changes_dir() / change
    found = []
    for name in ("proposal.md", "tasks.md"):
        path = folder / name
        if change and path.is_file() and not decided_after(folder, path):
            found += [(name, m.group(0).strip()) for m in SECTION.finditer(path.read_text())]
    return found


def blocked_text(change: str) -> str:
    """Every blocking section (not only `loop:` items), each prefixed with its file."""
    found = [f"{name}: {section}" for name, section in sections(change) if not loop_items(section)]
    return "\n\n".join(found)[:QUOTE_CHARS]


def loop_notes(change: str, artifacts: pathlib.Path) -> list[str]:
    """`loop: …` lines for the auditor: the items of loop-only sections and each line of loop-notes.md."""
    notes = [item for _, section in sections(change) for item in loop_items(section)]
    path = artifacts / "loop-notes.md"
    lines = [line.strip().lstrip("-* ").strip() for line in path.read_text().splitlines()] if path.is_file() else []
    notes += [line if LOOP_ITEM.match(line) else "loop: " + line for line in lines if line]
    return list(dict.fromkeys(notes))


def main() -> None:
    change = os.environ.get("INPUTS_CHANGE", "")
    text = blocked_text(change)
    if text:
        artifacts = pathlib.Path(os.environ.get("ARTIFACTS_DIR", "."))
        (artifacts / "escalation.md").write_text(f"# Judge: ask\n\n- blocked: {text}\n")
    print(json.dumps({"blocked": bool(text), "text": text}))


if __name__ == "__main__":
    main()
