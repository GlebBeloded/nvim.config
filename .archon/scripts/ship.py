"""Ship: archive the OpenSpec change (specs absorb the delta), commit the run branch, and merge it
into `auto` with --no-ff. Local only, nothing is pushed. The merge runs in the checkout that has
`auto` checked out (normally ~/.config/nvim) and refuses when that checkout has tracked edits;
without one it merges in a temporary worktree. The run's own worktree is removed afterwards by
`archon isolation cleanup --merged` (the make wrappers run it), because a run cannot delete the
directory it is executing in.
"""

import fcntl
import json
import os
import subprocess
import sys
import tempfile
import time

BASE = os.environ.get("BASE_BRANCH") or "auto"  # make targets pass --base auto
change = os.environ.get("INPUTS_CHANGE", "")
message = os.environ.get("INPUTS_MESSAGE", "") or (f"loop: {change}" if change else "loop: update")
LOCK_TIMEOUT = float(os.environ.get("SHIP_LOCK_TIMEOUT") or 600)
LOCK_POLL = 0.5


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


def read_holder(path: str) -> str | None:
    """Content of the lock file, None when there is none."""
    try:
        with open(path) as f:
            return f.read().strip()
    except FileNotFoundError:
        return None


def is_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def is_stale(holder: str) -> bool:
    return not holder.isdigit() or not is_alive(int(holder))


def try_lock(path: str) -> bool:
    """Creates the lock file with our pid atomically (a hard link fails if it exists), so it is
    never seen empty."""
    own = f"{path}.{os.getpid()}"
    with open(own, "w") as f:
        f.write(str(os.getpid()))
    try:
        os.link(own, path)
        return True
    except FileExistsError:
        return False
    finally:
        os.remove(own)


def remove_stale(path: str, holder: str) -> None:
    """Removes the lock if it still holds `holder`; a flock on its directory makes the check and the
    removal one step, so two takers cannot both remove it (the second would remove the first's)."""
    fd = os.open(os.path.dirname(path), os.O_RDONLY)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        if read_holder(path) == holder:
            os.remove(path)
    finally:
        os.close(fd)


def acquire_lock(path: str, timeout: float) -> None:
    deadline = time.monotonic() + timeout
    while not try_lock(path):
        holder = read_holder(path)
        if holder is None:
            continue
        if is_stale(holder):
            remove_stale(path, holder)
            continue
        if time.monotonic() >= deadline:
            fail(f"ship lock {path} held by pid {holder} for {timeout:g}s; delete it if that pid is not running")
        time.sleep(LOCK_POLL)


def release_lock(path: str) -> None:
    if read_holder(path) == str(os.getpid()):
        os.remove(path)


def is_mid_merge(target: str) -> bool:
    merge_head = subprocess.run(["git", "rev-parse", "-q", "--verify", "MERGE_HEAD"], cwd=target, capture_output=True)
    return merge_head.returncode == 0 or bool(git("status", "--porcelain", "--untracked-files=no", cwd=target))


def abort_merge(target: str, before: str) -> None:
    """Leaves `target` at `before` with no merge in progress and no tracked edits."""
    subprocess.run(["git", "merge", "--abort"], cwd=target, capture_output=True)
    if is_mid_merge(target):
        git("reset", "--merge", before, cwd=target)


def merge_into_base(branch: str) -> str:
    """Merges `branch` into BASE under the ship lock; returns the merge commit."""
    lock = os.path.join(os.path.abspath(git("rev-parse", "--git-common-dir")), "nvim-ship.lock")
    acquire_lock(lock, LOCK_TIMEOUT)
    try:
        return merge_locked(branch)
    finally:
        release_lock(lock)


def merge_locked(branch: str) -> str:
    target = base_checkout()
    temp = None
    if target is None:
        temp = tempfile.mkdtemp(prefix="nvim-ship-")
        git("worktree", "add", temp, BASE)
        target = temp
    elif git("status", "--porcelain", "--untracked-files=no", cwd=target):
        fail(f"{target} ({BASE}) has uncommitted changes; merge {branch} by hand: git merge --no-ff {branch}")

    before = git("rev-parse", "HEAD", cwd=target)
    merge = subprocess.run(
        ["git", "merge", "--no-ff", branch, "-m", f"Merge {branch} into {BASE}: {message}"],
        cwd=target,
        capture_output=True,
        text=True,
    )
    if merge.returncode != 0:
        abort_merge(target, before)
        fail(f"merge into {BASE} failed, branch {branch} kept:\n{merge.stdout}{merge.stderr}")
    commit = git("rev-parse", "--short", "HEAD", cwd=target)
    if temp:
        git("worktree", "remove", temp)
    return commit


if change and os.path.isdir(f"openspec/changes/{change}"):
    subprocess.run(["openspec", "archive", change, "--yes"], check=True, stdout=sys.stderr)  # stdout is the JSON result

branch = git("rev-parse", "--abbrev-ref", "HEAD")
git("add", "-A")
if git("status", "--porcelain"):
    git("commit", "-m", message)
if git("rev-list", "--count", f"{BASE}..{branch}") == "0":
    fail(f"nothing to ship: {branch} has no commits over {BASE}")

commit = merge_into_base(branch)
print(json.dumps({"merged": True, "branch": branch, "commit": commit}))
