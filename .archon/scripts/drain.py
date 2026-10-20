"""Bounded queue drain (`make drain [N=<max runs>]`): works queued changes one at a time through
`make queue CHANGE=<id>` in the foreground (so the Adopt rules of `make queue` apply; work-queue is
interactive-class, so Archon refuses `--detach`). The foreground CLI returns when the run completes,
fails or is cancelled (there are no manual gates; a `## Blocked` change runs too: its unblock step settles it); the run's status is then read from the Archon DB. It stops when the queue is empty, after N runs,
at the first paused run (no workflow node pauses any more: a loop bug, kept as a defensive stop), or at a run the stop-infra node cancelled (the sandbox
failed twice: the host is broken, so the next change would fail the same way; exit 1). Any other failed or cancelled run is recorded and the drain goes on. No change runs twice in one drain.
`make drains [LANES=2]` (`--lanes`) runs that many drains at once, each output line prefixed `[lane <k>]`: a lane picks
and starts its run under the pick lock (DRAIN_PICK_LOCK) until the run is recorded, so two lanes never take one change,
and a lane whose pick is empty while changes still wait on a `Depends:` change another live run works waits
(DRAIN_WAIT_S) instead of ending. Each `Depends:` edge whose two changes share no `## Impact` path is printed first:
an ordering-only dependency idles a lane, so drop it.
"""

import argparse
import fcntl
import json
import os
import pathlib
import re
import sqlite3
import subprocess
import sys
import tempfile
import threading
import time

SCRIPTS = pathlib.Path(__file__).resolve().parent
MAKE = os.environ.get("MAKE") or "make"


CHANGES = pathlib.Path("openspec/changes")
LANE_ENV = ("DRAIN_SKIP_FILE", "DRAIN_PICK_LOCK")
REGISTER_S = 300  # a started run shows up in the Archon DB well within this


def picked(skip: set[str]) -> dict:
    env = {**os.environ, "INPUTS_CHANGE": "", "QUEUE_SKIP": " ".join(sorted(skip))}
    out = subprocess.run(["python3", str(SCRIPTS / "queue_pick.py")], capture_output=True, text=True, check=True, env=env)
    return json.loads(out.stdout)


def pick(skip: set[str]) -> str:
    return picked(skip)["change"]


def pick_lock():
    """The host-wide pick lock: held from a lane's pick until its run is recorded (taken() then hides the change)."""
    path = pathlib.Path(os.environ.get("DRAIN_PICK_LOCK") or pathlib.Path.home() / ".cache" / "nvim-drain-pick.lock")
    path.parent.mkdir(parents=True, exist_ok=True)
    handle = path.open("w")
    fcntl.flock(handle, fcntl.LOCK_EX)
    return handle


def depends(change: str) -> list[str]:
    proposal = CHANGES / change / "proposal.md"
    lines = re.findall(r"^Depends:\s*(.+)$", proposal.read_text(), re.M) if proposal.exists() else []
    return [dep for line in lines for dep in re.split(r"[\s,]+", line.strip()) if dep]


def worked(waiting: list[str]) -> bool:
    """A live run (running or paused) works a change one of `waiting` depends on."""
    db = db_path()
    deps = {dep for change in waiting for dep in depends(change)}
    if not db.exists() or not deps:
        return False
    query = "select user_message from remote_agent_workflow_runs where status in ('running','paused')"
    with sqlite3.connect(f"file:{db}?mode=ro", uri=True) as conn:
        return any(row[0] in {f"Work queued change {dep}" for dep in deps} for row in conn.execute(query))


def impact_paths(change: str) -> set[str]:
    proposal = CHANGES / change / "proposal.md"
    if not proposal.exists():
        return set()
    section = re.split(r"(?m)^## Impact\s*$", proposal.read_text(), maxsplit=1)
    body = re.split(r"(?m)^## ", section[1])[0] if len(section) > 1 else ""
    return {path.rstrip("/") for raw in re.findall(r"`([\w./{},-]+/[\w./{},-]*)`", body) for path in braces(raw)}


def braces(path: str) -> list[str]:
    """`a/{b,c}.lua` as `a/b.lua` and `a/c.lua` (each group in turn)."""
    match = re.search(r"\{([^{}]*)\}", path)
    if not match:
        return [path]
    return [p for part in match.group(1).split(",") for p in braces(path[: match.start()] + part + path[match.end() :])]


def ordering_only() -> list[str]:
    """`Depends:` edges of queued changes whose two changes share no Impact path (nor one's folder holds the other's)."""
    lines = []
    for proposal in sorted(CHANGES.glob("*/proposal.md")):
        change = proposal.parent.name
        for dep in (d for d in depends(change) if (CHANGES / d / "proposal.md").exists()):
            mine, theirs = impact_paths(change), impact_paths(dep)
            if mine and theirs and not any(a == b or a.startswith(b + "/") or b.startswith(a + "/") for a in mine for b in theirs):
                lines.append(f"drain: {change} Depends: {dep}, but they share no Impact path: drop the line if only order matters")
    return lines


def db_path() -> pathlib.Path:
    return pathlib.Path(os.environ.get("ARCHON_DB") or pathlib.Path.home() / ".archon" / "archon.db")


def run_ids(change: str) -> set[str]:
    db = db_path()
    if not db.exists():
        return set()
    query = "select id from remote_agent_workflow_runs where user_message = ?"
    with sqlite3.connect(f"file:{db}?mode=ro", uri=True) as conn:
        return {row[0] for row in conn.execute(query, (f"Work queued change {change}",))}


def newest_run(change: str, before: set[str]) -> tuple[str, str] | None:
    """(id, status) of the newest run of `change` not in `before`."""
    db = db_path()
    if not db.exists():
        return None
    query = (
        "select id, status from remote_agent_workflow_runs where user_message = ?"
        " order by started_at desc, rowid desc"
    )
    with sqlite3.connect(f"file:{db}?mode=ro", uri=True) as conn:
        rows = conn.execute(query, (f"Work queued change {change}",)).fetchall()
    return next(((run_id, status) for run_id, status in rows if run_id not in before), None)


def stopped_on_infra(run_id: str) -> bool:
    """The run was cancelled by nvim-deliver's stop-infra node (`deliver__stop-infra` inside work-queue)."""
    query = "select 1 from remote_agent_workflow_events where workflow_run_id = ? and event_type = 'workflow_cancelled'"
    query += " and step_name like '%stop-infra'"
    try:
        with sqlite3.connect(f"file:{db_path()}?mode=ro", uri=True) as conn:
            return conn.execute(query, (run_id,)).fetchone() is not None
    except sqlite3.OperationalError:  # no events table: no node cancelled it
        return False


def run(change: str, lock=None) -> tuple[str, str]:
    """Works the change in the foreground (output streams through); returns its run id and
    `completed`, `failed`, `cancelled`, `infra` (stop-infra cancelled it) or `paused` (any other status
    still needs the user)."""
    env = {**os.environ, "MAKEFLAGS": "", "MAKELEVEL": ""}
    for name in LANE_ENV:  # the lanes' own state: a run's tests drain fixture queues, which must not share it
        env.pop(name, None)
    before = run_ids(change)
    proc = subprocess.Popen([MAKE, "-s", "queue", f"CHANGE={change}"], env=env)
    started = time.monotonic()
    while proc.poll() is None and not newest_run(change, before) and time.monotonic() - started < REGISTER_S:
        time.sleep(1)
    if lock:  # recorded (or ended): another lane's pick now skips it
        lock.close()
    proc.wait()
    found = newest_run(change, before)
    if not found:
        raise RuntimeError(f"make queue CHANGE={change} exited {proc.returncode} and recorded no run in {db_path()}")
    run_id, status = found
    if status == "cancelled" and stopped_on_infra(run_id):
        return run_id, "infra"
    return run_id, status if status in ("completed", "failed", "cancelled") else "paused"


def requeued(change: str) -> bool:
    """The judge rejected the run and followup.py re-queued the change (a `## Rejected run` section in its proposal)."""
    proposal = pathlib.Path("openspec/changes") / change / "proposal.md"
    return proposal.is_file() and "## Rejected run" in proposal.read_text()


def shared() -> set[str]:
    """Changes any lane of this `make drains` ran (DRAIN_SKIP_FILE: `+<change>` / `-<change>` lines, the last wins)."""
    path, names = os.environ.get("DRAIN_SKIP_FILE"), set()
    for line in pathlib.Path(path).read_text().splitlines() if path and os.path.exists(path) else []:
        (names.add if line.startswith("+") else names.discard)(line[1:])
    return names


def share(change: str, ran: bool) -> None:
    if os.environ.get("DRAIN_SKIP_FILE"):
        with open(os.environ["DRAIN_SKIP_FILE"], "a") as f:
            f.write(("+" if ran else "-") + change + "\n")


def drain(limit: int | None, lanes: bool = False) -> int:
    skip: set[str] = set()
    retried: set[str] = set()
    runs = 0
    while limit is None or runs < limit:
        lock = pick_lock() if lanes else None
        found = picked(skip | (shared() if lanes else set()))
        change = found["change"]
        if not change:
            lock and lock.close()
            if lanes and worked(found.get("waiting", [])):  # another lane works what they wait for
                time.sleep(float(os.environ.get("DRAIN_WAIT_S") or 60))
                continue
            print("drain: queue is empty")
            return 0
        skip.add(change)
        lanes and share(change, True)
        print(f"drain: {change} starting", flush=True)
        runs += 1
        run_id, status = run(change, lock)
        print(f"drain: {change} {status}", flush=True)
        if status == "cancelled" and change not in retried and requeued(change):  # one more run adopts its branch
            retried.add(change)
            skip.discard(change)
            lanes and share(change, False)
        if status == "paused":
            print(f"drain: stopped, {change} paused (no node should pause: a loop bug): archon workflow status (run {run_id})")
            return 0
        if status == "infra":
            print(f"drain: stopped, e2e sandbox infra failed twice on {change} (run {run_id}): fix the host, then rerun")
            return 1
    print(f"drain: stopped after {runs} run(s) (N={limit})")
    return 0


# host processes that starve the timing tests while drains run (gate logs, Oct 2026: torrents, Spotlight, an updater)
HOGS = ("transmission", "mds_stores", "mdworker", "mdsync", "logioptionsplus_updater")
HOG_CPU = 30.0
# three concurrent runs (two drains and a plugin update, Oct 2026) made every gate's timing layer flaky
MAX_LANES = int(os.environ.get("DRAIN_MAX_LANES") or 2)


def hogs() -> list[str]:
    """`drain: host busy` lines for HOGS processes above HOG_CPU % CPU."""
    out = subprocess.run(["ps", "-Ao", "pcpu=,comm="], capture_output=True, text=True).stdout
    lines = []
    for row in out.splitlines():
        cpu, _, comm = row.strip().partition(" ")
        name = comm.strip().rsplit("/", 1)[-1]
        if any(h in name.lower() for h in HOGS) and float(cpu or 0) >= HOG_CPU:
            lines.append(f"drain: host busy: {name} at {cpu}% CPU; timing tests flake under load, so pause it while drains run")
    return lines


def lanes(count: int, limit: int | None) -> int:
    """`count` drains at once (`--lane` children), each line prefixed `[lane <k>]`; the worst exit code."""
    for line in ordering_only() + hogs():
        print(line, flush=True)
    cmd = [sys.executable, __file__, "--lane"] + (["--max", str(limit)] if limit else [])
    fd, skip_file = tempfile.mkstemp(prefix="drain-skip-")
    os.close(fd)
    env = {**os.environ, "DRAIN_SKIP_FILE": skip_file}  # no lane reruns a change another lane ran
    procs = []
    for k in range(1, count + 1):
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env)

        def relay(proc=proc, k=k):
            for line in proc.stdout:
                print(f"[lane {k}] {line}", end="", flush=True)

        thread = threading.Thread(target=relay)
        thread.start()
        procs.append((proc, thread))
        time.sleep(float(os.environ.get("DRAIN_STAGGER_S") or 5))  # the first lane takes the pick lock first
    codes = []
    for proc, thread in procs:
        codes.append(proc.wait())
        thread.join()
    os.unlink(skip_file)
    return max(codes)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max", type=int, help="stop after this many runs (per lane)")
    parser.add_argument("--lanes", type=int, help="run this many drains at once")
    parser.add_argument("--lane", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    limit = args.max if args.max and args.max > 0 else None
    try:
        if args.lanes and args.lanes > MAX_LANES:
            print(f"drain: at most {MAX_LANES} lanes (DRAIN_MAX_LANES): more concurrent runs starve the timing tests", file=sys.stderr)
            return 2
        if args.lanes and args.lanes > 1:
            return lanes(args.lanes, limit)
        return drain(limit, lanes=args.lane)
    except (RuntimeError, sqlite3.Error, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        print(f"drain: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
