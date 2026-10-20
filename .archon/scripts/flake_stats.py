"""Known flaky test cases from the gates' own history: a case whose failure passed on its serial rerun
(`===== rerun <case>: ok =====` in a run's check log) in FLAKY_MIN runs or more within FLAKY_DAYS days, counting only
runs after its test file last changed (a fix starts its count over).
gate.py reruns these up to KNOWN_RERUNS times, like the hand-kept tests/flaky.txt (rerun statistics, as flaky-test
tools score them; the hand list missed half the repeat offenders, Oct 2026).
  flake_stats.py [runs dir]   prints `<count>  <file> | <case>`, most frequent first
"""

import os
import pathlib
import re
import subprocess
import sys
import time

FLAKY_MIN = int(os.environ.get("FLAKY_MIN") or 3)
FLAKY_DAYS = float(os.environ.get("FLAKY_DAYS") or 14)
RERUN_OK = re.compile(r"(?m)^===== rerun (tests/\S+\.lua) \| (.+?): ok =====$")
LABEL = re.compile(r" \(\d+/\d+, known flaky\)$")


def case_key(file: str, label: str) -> str:
    """`<file> | <cap>: <title>` of a rerun label, without the failure message after the title."""
    label = LABEL.sub("", label)
    cap, _, rest = label.partition(": ")
    title = rest.split(": ", 1)[0]
    return f"{file} | {cap}: {title}" if rest else f"{file} | {label}"


def changed_at(file: str, cache: dict[str, float]) -> float:
    """When the test file last changed on this checkout (its newest commit): a fix resets its case's history."""
    if file not in cache:
        out = subprocess.run(["git", "log", "-1", "--format=%ct", "--", file], capture_output=True, text=True).stdout
        cache[file] = float(out.strip() or 0)
    return cache[file]


def counts(runs: pathlib.Path) -> dict[str, int]:
    """Runs (not log lines) in which each case passed on rerun, within FLAKY_DAYS and after its file last changed."""
    cutoff, seen, changed = time.time() - FLAKY_DAYS * 86400, {}, {}
    for run in runs.iterdir() if runs.is_dir() else []:
        logs = [log for log in run.glob("*.log") if log.name.startswith(("check-", "full-", "quick-"))]
        newest = max((log.stat().st_mtime for log in logs), default=0)
        if newest < cutoff:
            continue
        keys = {
            case_key(f, label)
            for log in logs
            for f, label in RERUN_OK.findall(log.read_text(errors="replace"))
            if log.stat().st_mtime > changed_at(f, changed)
        }
        for key in keys:
            seen[key] = seen.get(key, 0) + 1
    return seen


def flaky_cases(runs: pathlib.Path) -> list[str]:
    return sorted(key for key, count in counts(runs).items() if count >= FLAKY_MIN)


if __name__ == "__main__":
    runs = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else pathlib.Path.home() / ".archon/workspaces/GlebBeloded/nvim.config/artifacts/runs")
    for key, count in sorted(counts(runs).items(), key=lambda kv: -kv[1]):
        if count >= FLAKY_MIN:
            print(f"{count:4d}  {key}")
