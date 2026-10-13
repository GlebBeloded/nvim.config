"""Remove the worktree and branch of loop runs that are done: a `loop/*` branch whose tip is on
`auto` (shipped: merged with --no-ff; superseded: an ancestor of `auto`). It never touches `auto`
or `main`, a branch with commits not on `auto` (listed as unmerged), a branch still at `auto`'s tip
(no commits yet), a branch a running or paused Archon run works (`ARCHON_DB`, default
~/.archon/archon.db), or a worktree with uncommitted or untracked changes (reported instead).

  loop_clean.py [--apply]                      every loop/* branch; dry run unless --apply (make loop-clean)
  loop_clean.py --branch B --apply --wait-pid P  one run (ship.py): waits until no live run holds B
                                               (without an Archon DB: until pid P exits), up to
                                               LOOP_CLEAN_WAIT s, then cleans B
"""

import argparse
import dataclasses
import os
import pathlib
import sqlite3
import subprocess
import sys
import time

BASE = os.environ.get("BASE_BRANCH") or "auto"
NEVER = {BASE, "auto", "main", "master"}
WAIT = float(os.environ.get("LOOP_CLEAN_WAIT") or 3600)
POLL = 2.0


def git(*args: str, cwd: str | None = None, check: bool = True) -> str:
    result = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, check=check)
    return result.stdout.strip()


def ok(*args: str, cwd: str | None = None) -> bool:
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True).returncode == 0


def real(path: str) -> str:
    return os.path.realpath(path)


@dataclasses.dataclass
class Branch:
    name: str
    worktree: str | None
    action: str = "keep"  # keep | remove
    reason: str = ""


def worktrees() -> dict[str, str]:
    """Branch name -> worktree path, for worktrees whose directory still exists."""
    found, path = {}, None
    for line in git("worktree", "list", "--porcelain").splitlines():
        if line.startswith("worktree "):
            path = line.removeprefix("worktree ")
        elif line.startswith("branch refs/heads/") and path and os.path.isdir(path):
            found[line.removeprefix("branch refs/heads/")] = path
    return found


def main_checkout() -> str:
    """The repo's main worktree: git runs there so removing a run's worktree never removes our cwd."""
    return git("worktree", "list", "--porcelain").splitlines()[0].removeprefix("worktree ")


def archon_db() -> pathlib.Path:
    return pathlib.Path(os.environ.get("ARCHON_DB") or pathlib.Path.home() / ".archon" / "archon.db")


def live_runs() -> list[tuple[str, str]] | None:
    """(status, working_path) of running or paused Archon runs; None when the DB cannot be read."""
    db = archon_db()
    if not db.exists():
        return []
    query = "select status, coalesce(working_path, '') from remote_agent_workflow_runs where status in ('running','paused')"
    try:
        with sqlite3.connect(f"file:{db}?mode=ro", uri=True) as conn:
            return conn.execute(query).fetchall()
    except sqlite3.Error:
        return None


def live_status(branch: Branch, runs: list[tuple[str, str]] | None) -> str | None:
    if runs is None:
        return "Archon runs unreadable"
    for status, path in runs:
        if path and ((branch.worktree and real(path) == real(branch.worktree)) or path.endswith("/" + branch.name)):
            return f"live run ({status})"
    return None


def shipped_tips() -> set[str]:
    """Second parents of the merges on BASE's first-parent history: the branches ship merged."""
    lines = git("rev-list", "--first-parent", "--merges", "--parents", BASE).splitlines()
    return {parents.split()[2] for parents in lines if len(parents.split()) > 2}


def dirty(worktree: str) -> bool:
    return bool(git("status", "--porcelain", cwd=worktree, check=False))


def classify(branch: Branch, runs: list[tuple[str, str]] | None, shipped: set[str]) -> None:
    tip, base = git("rev-parse", branch.name), git("rev-parse", BASE)
    live = live_status(branch, runs)
    if branch.name in NEVER or not branch.name.startswith("loop/"):
        branch.reason = "never cleaned"
    elif live:
        branch.reason = live
    elif tip == base:
        branch.reason = f"no commits yet (at {BASE})"
    elif not ok("merge-base", "--is-ancestor", tip, BASE):
        count = git("rev-list", "--count", f"{BASE}..{tip}")
        branch.reason = f"unmerged: {count} commit(s) not on {BASE}"
    elif branch.worktree and dirty(branch.worktree):
        branch.reason = f"uncommitted changes in {branch.worktree}"
    else:
        branch.action = "remove"
        branch.reason = "shipped" if tip in shipped else f"superseded (on {BASE})"


def remove(branch: Branch, cwd: str) -> str | None:
    """Removes the worktree, then the branch; returns an error message or None."""
    if branch.worktree:
        result = subprocess.run(["git", "worktree", "remove", "--force", branch.worktree], cwd=cwd, capture_output=True, text=True)
        if result.returncode != 0:
            return result.stderr.strip()
    result = subprocess.run(["git", "branch", "-D", branch.name], cwd=cwd, capture_output=True, text=True)
    return result.stderr.strip() if result.returncode != 0 else None


def report(branch: Branch, apply: bool, cwd: str) -> None:
    where = f"  {branch.worktree}" if branch.worktree and branch.action == "remove" else ""
    if branch.action == "remove" and apply:
        error = remove(branch, cwd)
        verb = f"FAILED  {branch.name}  {error}" if error else f"removed {branch.name}  {branch.reason}{where}"
        print(f"loop-clean: {verb}")
        return
    verb = "remove" if branch.action == "remove" else "keep  "
    print(f"loop-clean: {verb}  {branch.name}  {branch.reason}{where}")


def clean(names: list[str], apply: bool) -> list[Branch]:
    cwd = main_checkout()
    trees, runs, shipped = worktrees(), live_runs(), shipped_tips()
    branches = [Branch(name, trees.get(name)) for name in names]
    for branch in branches:
        classify(branch, runs, shipped)
    for branch in sorted(branches, key=lambda b: (b.action != "remove", b.name)):
        report(branch, apply, cwd)
    if apply:
        git("worktree", "prune", cwd=cwd)
    return branches


def pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def wait_until_done(branch: str, pid: int | None) -> bool:
    """Waits until no live Archon run holds `branch` and, without an Archon DB to tell, until `pid`
    has exited; False on timeout."""
    deadline = time.monotonic() + WAIT
    while time.monotonic() < deadline:
        live = live_status(Branch(branch, worktrees().get(branch)), live_runs())
        if not live and (archon_db().exists() or not (pid and pid_alive(pid))):
            return True
        time.sleep(POLL)
    return False


def all_loop_branches() -> list[str]:
    return git("for-each-ref", "--format=%(refname:short)", "refs/heads/loop/").splitlines()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--branch")
    parser.add_argument("--wait-pid", type=int)
    args = parser.parse_args()
    os.chdir(main_checkout())
    if args.branch:
        if not ok("rev-parse", "--verify", "--quiet", f"refs/heads/{args.branch}"):
            print(f"loop-clean: no branch {args.branch}")
            return 0
        if not wait_until_done(args.branch, args.wait_pid):
            print(f"loop-clean: keep    {args.branch}  run still live after {WAIT:.0f} s")
            return 0
        clean([args.branch], args.apply)
        return 0
    branches = clean(all_loop_branches(), args.apply)
    removing = sum(b.action == "remove" for b in branches)
    mode = "removed" if args.apply else "would remove (dry run; APPLY=1 to remove)"
    print(f"loop-clean: {removing} {mode}, {len(branches) - removing} kept")
    return 0


if __name__ == "__main__":
    sys.exit(main())
