"""Summary of a red `make check` log (tests/check.sh output) for the next fix pass: the status lines,
the head of every failed target section in log order (lint first), the failing test cases and
the log path, so an early section such as lint is never cut off by a tail. Fits in BUDGET chars
(verdict.py caps the whole feedback at 6000): each section gets an equal share of what is left.
"""

import re

ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
STATUS = re.compile(r"^(ok  |FAIL|skip) \S+ +[\d.]+ s|^check: ")
SECTION = re.compile(r"^===== (\S+) =====$")
FAIL_IN = re.compile(r"^FAIL in (.+?):?$")
NOISE = re.compile(r"^Total number of |^\S+\.lua \| .*: o+$")  # mini.test counts and passed cases (`oo` for a set)
SECTION_LINES = 30
LINE_CHARS = 160
FULL_CASES, CASE_CHARS = 5, 600  # the first failing cases keep their message (a stall's phase and subprocesses)
MAX_CASES = 20
BUDGET = 5000
MIN_SECTION_CHARS = 300


def strip_ansi(text: str) -> str:
    return ANSI.sub("", text)


def sections(lines: list[str]) -> list[tuple[str, list[str]]]:
    """Each `===== <target> =====` block of the failed-target logs, in log order."""
    found: list[tuple[str, list[str]]] = []
    for line in lines:
        match = SECTION.match(line)
        if match:
            found.append((match.group(1), []))
        elif found and not STATUS.match(line):
            found[-1][1].append(line)
    return found


FAILED = re.compile(r"^check: FAILED:((?: \S+)+) \(")


def failed_targets(text: str) -> list[str]:
    """Targets the `check: FAILED: <targets> (<s> s)` line of a check log names; empty when none."""
    match = next((m for line in text.splitlines() if (m := FAILED.match(line))), None)
    return match.group(1).split() if match else []


def failing_cases(lines: list[str]) -> list[str]:
    cases = []
    for line in lines:
        match = FAIL_IN.match(line)
        if match and match.group(1) not in cases:
            cases.append(match.group(1))
    return cases


def case_list(cases: list[str]) -> str:
    if not cases:
        return ""
    shown = "\n".join("- " + c[: CASE_CHARS if i < FULL_CASES else LINE_CHARS] for i, c in enumerate(cases[:MAX_CASES]))
    more = f"\n- … {len(cases) - MAX_CASES} more in the full log" if len(cases) > MAX_CASES else ""
    return "failing test cases (FAIL in):\n" + shown + more


def section_head(name: str, body: list[str], chars: int) -> str:
    head = "\n".join(line[:LINE_CHARS] for line in body if line.strip() and not NOISE.match(line))
    head = "\n".join(head.splitlines()[:SECTION_LINES])
    cut = "\n…" if len(head) > chars else ""
    return f"===== {name} (head) =====\n" + head[:chars] + cut


def summarize(text: str, log_path: str) -> str:
    lines = strip_ansi(text).splitlines()
    status = "\n".join(line for line in lines if STATUS.match(line))
    cases = case_list(failing_cases(lines))
    found = sections(lines)
    used = len(log_path) + len(status) + len(cases) + 40
    share = max(MIN_SECTION_CHARS, (BUDGET - used) // max(len(found), 1) - 30)
    parts = [f"full log: {log_path}", status]
    parts += [section_head(name, body, share) for name, body in found]
    parts.append(cases)
    return "\n\n".join(p for p in parts if p.strip())
