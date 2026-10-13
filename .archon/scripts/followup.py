"""After a rejected run: queue a follow-up OpenSpec change on `auto` (under the ship lock) that names
the kept branch and the judge's reasons, so `make queue`/`make drain` picks the work up again. No AI.
Prints {queued, change}.
"""

import json
import os
import subprocess
import tempfile

from shiplock import acquire_lock, lock_path, release_lock

BASE = os.environ.get("BASE_BRANCH") or "auto"
change = os.environ.get("INPUTS_CHANGE", "") or "change"
reasons = os.environ.get("INPUTS_REASONS", "").strip() or "- unknown"


def git(*args: str, cwd: str | None = None) -> str:
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, check=True).stdout.strip()


def base_checkout() -> str | None:
    path = None
    for line in git("worktree", "list", "--porcelain").splitlines():
        if line.startswith("worktree "):
            path = line.removeprefix("worktree ")
        elif line == f"branch refs/heads/{BASE}":
            return path
    return None


def write_change(root: str, name: str, branch: str) -> None:
    folder = os.path.join(root, "openspec/changes", name)
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, ".openspec.yaml"), "w") as f:
        f.write("schema: spec-driven\n")
    with open(os.path.join(folder, "proposal.md"), "w") as f:
        f.write(
            f"## Why\nRun on `{branch}` for `{change}` was rejected by the judge:\n{reasons}\n\nKind: bug\n\n"
            f"## What Changes\n- Continue from branch `{branch}`: merge it, fix the reasons above, ship.\n\n"
            f"## Impact\n- Same scope as `{change}`. Out of scope: anything else.\n"
        )


branch = git("rev-parse", "--abbrev-ref", "HEAD")
name = f"followup-{change}"[:60]
lock = lock_path()
acquire_lock(lock, 600)
try:
    target = base_checkout()
    temp = None
    if target is not None and git("status", "--porcelain", "--untracked-files=no", cwd=target):
        print(json.dumps({"queued": False, "change": name, "reason": f"{target} has uncommitted changes"}))
        raise SystemExit(0)
    if target is None:
        temp = tempfile.mkdtemp(prefix="nvim-followup-")
        git("worktree", "add", "--detach", temp, BASE)
    root = temp or target
    write_change(root, name, branch)
    git("add", "openspec/changes/" + name, cwd=root)
    git("commit", "-q", "-m", f"chore(openspec): queue {name}", cwd=root)
    if temp:
        git("update-ref", f"refs/heads/{BASE}", git("rev-parse", "HEAD", cwd=temp))
        git("worktree", "remove", "--force", temp)
finally:
    release_lock(lock)
print(json.dumps({"queued": True, "change": name}))
