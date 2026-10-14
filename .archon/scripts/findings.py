"""Review findings split by weight, shared by verdict.py (only blocking ones go to the fix pass) and
escalation.py (minor ones are listed as notes on ship). When unsure, a line is blocking (fail safe)."""

import re

MINOR_CHARS = 300  # per minor finding listed as a note
MINOR_MARK = re.compile(r"\[(minor|nit|non-blocking)\]|\b(minor|nit|non-blocking)\b\s*[:)]", re.IGNORECASE)
MINOR_HEAD = re.compile(r"^\W*(minor|nits?|non-blocking)\b[^:]*:$", re.IGNORECASE)  # "Minor (non-blocking):"
BLOCKING_HEAD = re.compile(r"^\W*(must[- ]fix|blocking)\b[^:]*:$", re.IGNORECASE)  # "Must-fix:", "Blocking findings:"
# `1. [must-fix] …`, `- blocking: …`: blocking wherever it stands, under a Minor heading too
BLOCKING_MARK = re.compile(r"\[(must[- ]fix|blocking)\]|^[\W\d]*(must[- ]fix|blocking)\b\s*[:)]", re.IGNORECASE)
ITEM = re.compile(r"^(\d+[.)]|[-*•]\s|\[)")  # a line that starts a finding; others continue the one above


def split_findings(text: str) -> tuple[list[str], list[str]]:
    """(blocking, minor) non-empty lines: minor ones are marked minor or non-blocking (`[minor]`, `minor:`)
    or under a `Minor …:` heading (a `Must-fix …:`/`Blocking …:` heading ends it), and a finding's continuation
    lines go with it; a `[must-fix]` line is always blocking; headings are neither."""
    blocking, minor, under, prev = [], [], False, None
    for line in (raw.strip() for raw in text.splitlines()):
        if not line:
            prev = None  # a blank line ends a finding
            continue
        if MINOR_HEAD.match(line) or BLOCKING_HEAD.match(line):
            under, prev = bool(MINOR_HEAD.match(line)), None
            continue
        if prev and not ITEM.match(line) and not BLOCKING_MARK.search(line):  # continues the finding above
            found = minor if prev == "minor" else blocking
            found[-1] = (found[-1] + " " + line)[: MINOR_CHARS if prev == "minor" else None]
            continue
        blocked = BLOCKING_MARK.search(line) or not (under or MINOR_MARK.search(line))
        prev = "blocking" if blocked else "minor"
        (blocking if blocked else minor).append(line if blocked else line[:MINOR_CHARS])
    return blocking, minor


def minor_findings(text: str) -> list[str]:
    return split_findings(text)[1]


def blocking_findings(text: str) -> str:
    """The findings for the fix pass: the blocking lines, or the whole text when every line is minor (a
    rejecting review still needs a fix)."""
    blocking = split_findings(text)[0]
    return "\n".join(blocking) if blocking else text.strip()
