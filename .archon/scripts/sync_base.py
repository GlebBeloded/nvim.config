"""Merge the base branch into the run's branch before a gate, when the base moved and the merge is clean
(run e15e8b69: the branch forked from an auto whose loop tests were red, so every gate failed on them although
auto had the fix, and the approved renders committed to auto later never reached the branch). Skipped with
tracked edits left in the worktree; a conflicting merge is aborted, and the gate then runs as before
(ship's reconcile loop resolves it). Returns a one-line note, or "" when nothing changed.
"""

import os
import subprocess

BASE = os.environ.get("BASE_BRANCH") or "auto"


def _git(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], capture_output=True, text=True)


def sync() -> str:
    if _git("rev-parse", "--verify", "-q", BASE).returncode != 0:
        return ""
    if _git("merge-base", "--is-ancestor", BASE, "HEAD").returncode == 0:
        return ""
    if _git("status", "--porcelain", "--untracked-files=no").stdout.strip():
        return f"sync: {BASE} moved, not merged (tracked edits in the worktree)"
    merged = _git("merge", "--no-edit", "-m", f"Merge {BASE} into the run branch before the gate", BASE)
    if merged.returncode != 0:
        _git("merge", "--abort")
        return f"sync: {BASE} moved, merge conflicts (left to ship's reconcile)"
    return f"sync: merged {BASE}"


if __name__ == "__main__":
    print(sync())
