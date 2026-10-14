"""Review findings split by weight, shared by verdict.py (only blocking ones go to the fix pass) and
escalation.py (minor ones are listed as notes on ship)."""

import re

MINOR_CHARS = 300  # per minor finding listed as a note
MINOR_MARK = re.compile(r"\[(minor|nit|non-blocking)\]|\b(minor|nit|non-blocking)\b\s*[:)]", re.IGNORECASE)
MINOR_HEAD = re.compile(r"^\W*(minor|nits?|non-blocking)\b[^:]*:$", re.IGNORECASE)  # "Minor (non-blocking):"
BLOCKING_HEAD = re.compile(r"^\W*(\[?must[- ]fix|\[?blocking)\b", re.IGNORECASE)


def split_findings(text: str) -> tuple[list[str], list[str]]:
    """(blocking, minor) non-empty lines: minor ones are marked minor or non-blocking (`[minor]`, `minor:`)
    or under a `Minor …:` heading (a `[must-fix]`/`Blocking` heading ends it); the heading itself is neither."""
    blocking, minor, under = [], [], False
    for line in (raw.strip() for raw in text.splitlines()):
        if MINOR_HEAD.match(line):
            under = True
            continue
        if BLOCKING_HEAD.match(line):
            under = False
        if line and (under or MINOR_MARK.search(line)) and not BLOCKING_HEAD.match(line):
            minor.append(line[:MINOR_CHARS])
        elif line:
            blocking.append(line)
    return blocking, minor


def minor_findings(text: str) -> list[str]:
    return split_findings(text)[1]


def blocking_findings(text: str) -> str:
    """The findings for the fix pass: the blocking lines, or the whole text when every line is minor (a
    rejecting review still needs a fix)."""
    blocking = split_findings(text)[0]
    return "\n".join(blocking) if blocking else text.strip()
