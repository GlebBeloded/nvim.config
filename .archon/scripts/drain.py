"""Bounded queue drain (`make drain [N=<max runs>]`): works queued changes one at a time through
`make queue CHANGE=<id>` in the foreground (so the Adopt rules of `make queue` apply; work-queue is
interactive-class, so Archon refuses `--detach`). The foreground CLI returns when the run completes,
fails or is cancelled (there are no manual gates; a `## Blocked` change runs too: its unblock step settles it); the run's status is then read from the Archon DB. It stops when the queue is empty, after N runs,
at the first paused run (no workflow node pauses any more: a loop bug, kept as a defensive stop), or at a run the stop-infra node cancelled (the sandbox
failed twice: the host is broken, so the next change would fail the same way; exit 1). Any other failed or cancelled run is recorded and the drain goes on. No change runs twice in one drain.
"""

import argparse
import json
import os
import pathlib
import sqlite3
import subprocess
import sys

SCRIPTS = pathlib.Path(__file__).resolve().parent
MAKE = os.environ.get("MAKE") or "make"


def pick(skip: set[str]) -> str:
    env = {**os.environ, "INPUTS_CHANGE": "", "QUEUE_SKIP": " ".join(sorted(skip))}
    out = subprocess.run(["python3", str(SCRIPTS / "queue_pick.py")], capture_output=True, text=True, check=True, env=env)
    return json.loads(out.stdout)["change"]


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


def run(change: str) -> tuple[str, str]:
    """Works the change in the foreground (output streams through); returns its run id and
    `completed`, `failed`, `cancelled`, `infra` (stop-infra cancelled it) or `paused` (any other status
    still needs the user)."""
    env = {**os.environ, "MAKEFLAGS": "", "MAKELEVEL": ""}
    before = run_ids(change)
    out = subprocess.run([MAKE, "-s", "queue", f"CHANGE={change}"], env=env)
    found = newest_run(change, before)
    if not found:
        raise RuntimeError(f"make queue CHANGE={change} exited {out.returncode} and recorded no run in {db_path()}")
    run_id, status = found
    if status == "cancelled" and stopped_on_infra(run_id):
        return run_id, "infra"
    return run_id, status if status in ("completed", "failed", "cancelled") else "paused"


def requeued(change: str) -> bool:
    """The judge rejected the run and followup.py re-queued the change (a `## Rejected run` section in its proposal)."""
    proposal = pathlib.Path("openspec/changes") / change / "proposal.md"
    return proposal.is_file() and "## Rejected run" in proposal.read_text()


def drain(limit: int | None) -> int:
    skip: set[str] = set()
    retried: set[str] = set()
    runs = 0
    while limit is None or runs < limit:
        change = pick(skip)
        if not change:
            print("drain: queue is empty")
            return 0
        skip.add(change)
        print(f"drain: {change} starting", flush=True)
        runs += 1
        run_id, status = run(change)
        print(f"drain: {change} {status}", flush=True)
        if status == "cancelled" and change not in retried and requeued(change):  # one more run adopts its branch
            retried.add(change)
            skip.discard(change)
        if status == "paused":
            print(f"drain: stopped, {change} paused (no node should pause: a loop bug): archon workflow status (run {run_id})")
            return 0
        if status == "infra":
            print(f"drain: stopped, e2e sandbox infra failed twice on {change} (run {run_id}): fix the host, then rerun")
            return 1
    print(f"drain: stopped after {runs} run(s) (N={limit})")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max", type=int, help="stop after this many runs")
    args = parser.parse_args()
    try:
        return drain(args.max if args.max and args.max > 0 else None)
    except (RuntimeError, sqlite3.Error, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        print(f"drain: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
