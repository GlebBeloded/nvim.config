"""Ship: archive the OpenSpec change (specs absorb the delta), commit the run branch, and merge it
into `auto` with --no-ff. Local only, nothing is pushed. The merge runs in the checkout that has
`auto` checked out (normally ~/.config/nvim) and refuses when that checkout has tracked edits;
without one it merges in a temporary worktree. Merges into `auto` run one at a time under a pid lock
file in the common git dir (`nvim-ship.lock`; a lock whose pid is gone is taken over), and a failed
merge is aborted back to the pre-merge commit. A content conflict fails the run, or with
`INPUTS_ON_CONFLICT=report` prints `{"merged": false, "conflict": true, "files": [...]}` and exits 0
so the workflow can reconcile the branch. The run's own worktree is removed afterwards by
`archon isolation cleanup --merged` (the make wrappers run it), because a run cannot delete the
directory it is executing in.
"""

import json
import os
import subprocess
import sys
import tempfile

from shiplock import acquire_lock, lock_path, release_lock

BASE = os.environ.get("BASE_BRANCH") or "auto"  # make targets pass --base auto
change = os.environ.get("INPUTS_CHANGE", "")
message = os.environ.get("INPUTS_MESSAGE", "") or (f"loop: {change}" if change else "loop: update")
on_conflict = os.environ.get("INPUTS_ON_CONFLICT", "") or "fail"
LOCK_TIMEOUT = float(os.environ.get("SHIP_LOCK_TIMEOUT") or 600)


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


def is_mid_merge(target: str) -> bool:
    merge_head = subprocess.run(["git", "rev-parse", "-q", "--verify", "MERGE_HEAD"], cwd=target, capture_output=True)
    return merge_head.returncode == 0 or bool(git("status", "--porcelain", "--untracked-files=no", cwd=target))


def abort_merge(target: str, before: str) -> None:
    """Leaves `target` at `before` with no merge in progress and no tracked edits."""
    subprocess.run(["git", "merge", "--abort"], cwd=target, capture_output=True)
    if is_mid_merge(target):
        git("reset", "--merge", before, cwd=target)


def conflicting_files(branch: str) -> list[str]:
    """Files `branch` conflicts on with BASE, computed without touching any checkout."""
    tree = subprocess.run(
        ["git", "merge-tree", "--write-tree", "--name-only", BASE, branch], capture_output=True, text=True
    )
    if tree.returncode != 1:
        return []
    return tree.stdout.split("\n\n", 1)[0].splitlines()[1:]  # the tree, then the conflicting names


def merge_into_base(branch: str) -> str | None:
    """Merges `branch` into BASE under the ship lock; returns the merge commit, None on a conflict
    that is reported."""
    lock = lock_path()
    acquire_lock(lock, LOCK_TIMEOUT)
    try:
        return merge_locked(branch)
    finally:
        release_lock(lock)


def merge_locked(branch: str) -> str | None:
    target = base_checkout()
    if target is not None:
        if git("status", "--porcelain", "--untracked-files=no", cwd=target):
            fail(f"{target} ({BASE}) has uncommitted changes; merge {branch} by hand: git merge --no-ff {branch}")
        return merge_in(target, branch)
    temp = tempfile.mkdtemp(prefix="nvim-ship-")
    git("worktree", "add", temp, BASE)
    try:
        return merge_in(temp, branch)
    finally:
        git("worktree", "remove", "--force", temp)


def merge_in(target: str, branch: str) -> str | None:
    """Merges `branch` in the clean `target` checkout of BASE; on failure leaves it at its
    pre-merge commit."""
    before = git("rev-parse", "HEAD", cwd=target)
    merge = subprocess.run(
        ["git", "merge", "--no-ff", branch, "-m", f"Merge {branch} into {BASE}: {message}"],
        cwd=target,
        capture_output=True,
        text=True,
    )
    if merge.returncode == 0:
        return git("rev-parse", "--short", "HEAD", cwd=target)
    abort_merge(target, before)
    files = conflicting_files(branch)
    if files and on_conflict == "report":
        print(json.dumps({"merged": False, "conflict": True, "branch": branch, "commit": "", "files": files}))
        return None
    fail(f"merge into {BASE} failed, branch {branch} kept:\n{merge.stdout}{merge.stderr}")


if change and os.path.isdir(f"openspec/changes/{change}"):
    subprocess.run(["openspec", "archive", change, "--yes"], check=True, stdout=sys.stderr)  # stdout is the JSON result

branch = git("rev-parse", "--abbrev-ref", "HEAD")
git("add", "-A")
if git("status", "--porcelain"):
    git("commit", "-m", message)
if git("rev-list", "--count", f"{BASE}..{branch}") == "0":
    fail(f"nothing to ship: {branch} has no commits over {BASE}")

commit = merge_into_base(branch)
if commit is not None:
    print(json.dumps({"merged": True, "conflict": False, "branch": branch, "commit": commit}))
