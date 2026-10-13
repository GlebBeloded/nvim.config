"""Persist verified loop lessons in the bounded section of docs/workflow.md."""

import re
from pathlib import Path

LIMIT = 10
WORKFLOW = Path("docs/workflow.md")
CANDIDATES = "lesson-candidates.txt"
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


def append_unique(lessons: list[str], candidate: str) -> None:
    folded = candidate.casefold()
    lessons[:] = [lesson for lesson in lessons if lesson.casefold() != folded]
    lessons.append(candidate)


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
