"""Ship: archive the OpenSpec change (specs absorb the delta), commit the run branch, and merge it
into `auto` with --no-ff. Local only, nothing is pushed. The merge runs in the checkout that has
`auto` checked out (normally ~/.config/nvim) and refuses when that checkout has tracked edits;
without one it merges in a temporary worktree. The run's own worktree is removed afterwards by
`archon isolation cleanup --merged` (the make wrappers run it), because a run cannot delete the
directory it is executing in.
"""

import json
import os
import subprocess
import sys
import tempfile

BASE = os.environ.get("BASE_BRANCH") or "auto"  # make targets pass --base auto
change = os.environ.get("INPUTS_CHANGE", "")
message = os.environ.get("INPUTS_MESSAGE", "") or (f"loop: {change}" if change else "loop: update")


def git(*args: str, cwd: str | None = None) -> str:
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, check=True).stdout.strip()


def fail(msg: str) -> None:
    print(msg, file=sys.stderr)
    sys.exit(1)


def base_checkout() -> str | None:
    path = None
    for line in git("worktree", "list", "--porcelain").splitlines():
        if line.startswith("worktree "):
            path = line.removeprefix("worktree ")
        elif line == f"branch refs/heads/{BASE}":
            return path
    return None


if change and os.path.isdir(f"openspec/changes/{change}"):
    subprocess.run(["openspec", "archive", change, "--yes"], check=True)

branch = git("rev-parse", "--abbrev-ref", "HEAD")
git("add", "-A")
if git("status", "--porcelain"):
    git("commit", "-m", message)
if git("rev-list", "--count", f"{BASE}..{branch}") == "0":
    fail(f"nothing to ship: {branch} has no commits over {BASE}")

target = base_checkout()
temp = None
if target is None:
    temp = tempfile.mkdtemp(prefix="nvim-ship-")
    git("worktree", "add", temp, BASE)
    target = temp
elif git("status", "--porcelain", "--untracked-files=no", cwd=target):
    fail(f"{target} ({BASE}) has uncommitted changes; merge {branch} by hand: git merge --no-ff {branch}")

merge = subprocess.run(
    ["git", "merge", "--no-ff", branch, "-m", f"Merge {branch} into {BASE}: {message}"],
    cwd=target,
    capture_output=True,
    text=True,
)
if merge.returncode != 0:
    subprocess.run(["git", "merge", "--abort"], cwd=target)
    fail(f"merge into {BASE} failed, branch {branch} kept:\n{merge.stdout}{merge.stderr}")
commit = git("rev-parse", "--short", "HEAD", cwd=target)
if temp:
    git("worktree", "remove", temp)
print(json.dumps({"merged": True, "branch": branch, "commit": commit}))
