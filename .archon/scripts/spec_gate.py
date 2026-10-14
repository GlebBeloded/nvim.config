"""The work-queue spec gate: strict validate, a trial archive (spec_trial.py), task scenario names
(scenarios.py --unknown) and planned pins (pinned.py --check) for INPUTS_CHANGE, stopping at the first
failing check. Prints {ok, log} and exits 0, so a red first pass routes back to the spec step
(`spec-retry`, which gets the log) instead of failing the run.

With INPUTS_FAILED_LOG set (the `spec-failed` node, after a red second pass) it prints that log to
stderr and exits 1: the run fails with it.
"""

import json
import os
import subprocess
import sys

LOG_CHARS = 4000


def checks(change: str) -> list[list[str]]:
    scripts = os.path.dirname(os.path.abspath(__file__))
    return [
        ["openspec", "validate", change, "--strict", "--no-interactive"],
        [sys.executable, os.path.join(scripts, "spec_trial.py"), change],
        [sys.executable, os.path.join(scripts, "scenarios.py"), "--unknown", change],
        [sys.executable, os.path.join(scripts, "pinned.py"), "--check", change],
    ]


def gate(change: str) -> dict:
    for cmd in checks(change):
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode != 0:
            name = os.path.basename(cmd[1]) if cmd[0] == sys.executable else " ".join(cmd[:2])
            out = (proc.stdout + proc.stderr).strip()
            return {"ok": False, "log": f"{name} failed (exit {proc.returncode}):\n{out}"[-LOG_CHARS:]}
    return {"ok": True, "log": ""}


if __name__ == "__main__":
    failed = os.environ.get("INPUTS_FAILED_LOG", "").strip()
    if failed:
        print(f"spec gate failed twice:\n{failed}", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(gate(os.environ.get("INPUTS_CHANGE", ""))))
