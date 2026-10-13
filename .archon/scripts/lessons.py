"""Persist verified loop lessons in the bounded section of docs/workflow.md: the LIMIT newest, a
candidate replacing any exact or near duplicate (difflib ratio >= NEAR on lowercased words). A
`loop:` candidate is about loop tooling (a false positive of a loop check) and is never persisted.
Candidates a pass wrote are dropped when that pass's review rejected the change (`drop_overturned`, run by
verdict.py). Persisted candidates are cleared, so a later call (a reconcile pass, a second judge) never merges
them again."""

import re
from pathlib import Path

LIMIT = 15
NEAR = 0.8
TOOLING = re.compile(r"^loop:", re.IGNORECASE)
WORKFLOW = Path("docs/workflow.md")
CANDIDATES = "lesson-candidates.txt"
KEPT = "lesson-candidates.kept"  # candidate lines verdict.py has already let stand
HEADING = re.compile(r"^## Loop lessons(?:\r?\n|$)", re.MULTILINE)
NEXT_HEADING = re.compile(r"^## [^\r\n]+(?:\r?\n|$)", re.MULTILINE)


def normalize(lesson: str) -> str:
    normalized = " ".join(lesson.split())
    if not normalized:
        raise ValueError("lesson candidates must be non-empty one-line entries")
    return normalized


def section(text: str) -> tuple[int, int, str, list[str]]:
    headings = list(HEADING.finditer(text))
    if len(headings) != 1:
        raise ValueError("docs/workflow.md must contain exactly one Loop lessons section")
    heading = headings[0]
    boundary = NEXT_HEADING.search(text, heading.end())
    if boundary is None:
        raise ValueError("Loop lessons must be followed by another level-two section")

    body = text[heading.end() : boundary.start()]
    lessons = []
    for line in body.splitlines():
        if not line.strip():
            continue
        if not line.startswith("- ") or not line[2:].strip():
            raise ValueError("Loop lessons may contain only one-line bullets")
        lessons.append(normalize(line[2:]))
    newline = "\r\n" if heading.group(0).endswith("\r\n") else "\n"
    return heading.end(), boundary.start(), newline, lessons


def words(lesson: str) -> set[str]:
    return set(re.findall(r"[a-z0-9]+", lesson.casefold()))


def duplicate(a: str, b: str) -> bool:
    union = words(a) | words(b)
    return not union or len(words(a) & words(b)) / len(union) >= NEAR


def append_unique(lessons: list[str], candidate: str) -> None:
    if TOOLING.match(candidate):
        return
    lessons[:] = [lesson for lesson in lessons if not duplicate(lesson, candidate)]
    lessons.append(candidate)


def drop_overturned(artifacts: Path, overturned: bool) -> None:
    """End of a pass: when its review rejected the change, drop the candidates written since the last
    pass ended; then record how many lines stand."""
    path, kept = artifacts / CANDIDATES, artifacts / KEPT
    lines = path.read_text().splitlines() if path.exists() else []
    before = int(kept.read_text() or 0) if kept.exists() else 0
    if overturned and len(lines) > before:
        lines = lines[:before]
        path.write_text("".join(line + "\n" for line in lines))
    kept.write_text(str(len(lines)))


def persist_lessons(artifacts: Path, workflow: Path = WORKFLOW) -> None:
    candidates_path = artifacts / CANDIDATES
    if not candidates_path.exists():
        return
    candidates = [normalize(line) for line in candidates_path.read_text().splitlines()]
    if not candidates:
        return

    text = workflow.read_text()
    body_start, body_end, newline, lessons = section(text)
    for candidate in candidates:
        append_unique(lessons, candidate)
    lessons = lessons[-LIMIT:]
    body = newline + newline.join("- " + lesson for lesson in lessons) + newline * 2
    workflow.write_text(text[:body_start] + body + text[body_end:])
    candidates_path.write_text("")
    (artifacts / KEPT).write_text("0")
