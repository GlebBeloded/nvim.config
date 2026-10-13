"""The ship lock: merges into `auto` (ship.py, followup.py) run one at a time under a pid lock file in
the common git dir (`nvim-ship.lock`); a lock whose pid is gone is taken over."""

import fcntl
import os
import subprocess
import sys
import time

LOCK_POLL = 0.5


def fail(msg: str) -> None:
    print(msg, file=sys.stderr)
    sys.exit(1)


def lock_path() -> str:
    common = subprocess.run(["git", "rev-parse", "--git-common-dir"], capture_output=True, text=True, check=True)
    return os.path.join(os.path.abspath(common.stdout.strip()), "nvim-ship.lock")


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


