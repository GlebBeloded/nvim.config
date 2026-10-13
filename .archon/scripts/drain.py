"""Bounded queue drain (`make drain [N=<max runs>]`): works queued changes one at a time through
`make queue CHANGE=<id> DETACH=1` (so the Adopt rules of `make queue` apply) and waits for each run
with `archon workflow wait`. It stops when the queue is empty, after N runs, or at the first run that
pauses for the user (a gate, a Blocked section). A change with a `## Blocked` section is skipped, not
run; a failed or cancelled run is recorded and the drain goes on. No change runs twice in one drain.
"""

import argparse
import json
import os
import pathlib
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blocked import blocked_text  # noqa: E402

SCRIPTS = pathlib.Path(__file__).resolve().parent
ARCHON = os.environ.get("ARCHON") or "archon"
MAKE = os.environ.get("MAKE") or "make"


def pick(skip: set[str]) -> str:
    env = {**os.environ, "INPUTS_CHANGE": "", "QUEUE_SKIP": " ".join(sorted(skip))}
    out = subprocess.run(["python3", str(SCRIPTS / "queue_pick.py")], capture_output=True, text=True, check=True, env=env)
    return json.loads(out.stdout)["change"]


def first_json(text: str) -> dict:
    """The first JSON object in `text` (make prints `Working on …` lines before Archon's JSON)."""
    start = text.find("{")
    if start < 0:
        raise ValueError(f"no JSON in: {text.strip()[-500:]}")
    return json.JSONDecoder().raw_decode(text[start:])[0]


def start(change: str) -> str:
    """Starts the change's work-queue run detached; returns its run id."""
    env = {**os.environ, "MAKEFLAGS": "", "MAKELEVEL": ""}
    cmd = [MAKE, "-s", "queue", f"CHANGE={change}", "DETACH=1"]
    out = subprocess.run(cmd, capture_output=True, text=True, env=env)
    if out.returncode != 0:
        raise RuntimeError(f"make queue CHANGE={change} failed:\n{out.stdout}{out.stderr}")
    run_id = first_json(out.stdout).get("runId")
    if not run_id:
        raise RuntimeError(f"make queue CHANGE={change} printed no runId:\n{out.stdout}")
    return run_id


def wait(run_id: str) -> str:
    """Blocks until the run ends or needs the user: `completed`, `failed`, `cancelled` or `paused`."""
    out = subprocess.run([ARCHON, "workflow", "wait", run_id, "--json"], capture_output=True, text=True)
    payload = first_json(out.stdout)
    attention = payload.get("attention") or {}
    if attention.get("kind") == "terminal":
        return attention.get("status") or "failed"
    return "paused"


def drain(limit: int | None) -> int:
    skip: set[str] = set()
    runs = 0
    while limit is None or runs < limit:
        change = pick(skip)
        if not change:
            print("drain: queue is empty")
            return 0
        skip.add(change)
        if blocked_text(change):
            print(f"drain: skip {change} (Blocked)")
            continue
        run_id = start(change)
        runs += 1
        print(f"drain: {change} started (run {run_id})", flush=True)
        status = wait(run_id)
        print(f"drain: {change} {status}", flush=True)
        if status == "paused":
            print(f"drain: stopped, {change} waits for you: archon workflow status (run {run_id})")
            return 0
    print(f"drain: stopped after {runs} run(s) (N={limit})")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max", type=int, help="stop after this many runs")
    args = parser.parse_args()
    try:
        return drain(args.max if args.max and args.max > 0 else None)
    except (RuntimeError, ValueError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        print(f"drain: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
