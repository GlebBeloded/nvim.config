"""Test gate for one build iteration: make check (lint, types, tests, smoke, trace), strict OpenSpec
validation of the change, and tasks.md completion. Never fails the node: prints one JSON verdict so
the build loop can feed failures back to the next implement pass. Counts attempts in ARTIFACTS_DIR.
"""

import json
import os
import pathlib
import subprocess

change = os.environ.get("INPUTS_CHANGE", "")
artifacts = pathlib.Path(os.environ.get("ARTIFACTS_DIR", "."))
counter = artifacts / "attempts"
attempt = int(counter.read_text()) + 1 if counter.exists() else 1
counter.write_text(str(attempt))


def run(cmd: list[str], log: str) -> tuple[bool, str]:
    proc = subprocess.run(cmd, capture_output=True, text=True)
    out = proc.stdout + proc.stderr
    (artifacts / log).write_text(out)
    return proc.returncode == 0, "\n".join(out.splitlines()[-40:])


green, check_tail = run(["make", "check"], f"check-{attempt}.log")
spec_ok, spec_tail = True, ""
tasks_done = True
change_dir = pathlib.Path("openspec/changes") / change
if change and change_dir.is_dir():
    spec_ok, spec_tail = run(["openspec", "validate", change, "--strict", "--no-interactive"], f"validate-{attempt}.log")
    tasks = change_dir / "tasks.md"
    tasks_done = tasks.exists() and "- [ ]" not in tasks.read_text()

failures = []
if not green:
    failures.append("make check is red:\n" + check_tail)
if not spec_ok:
    failures.append("openspec validate --strict failed:\n" + spec_tail)
if not tasks_done:
    failures.append(f"openspec/changes/{change}/tasks.md has unchecked tasks")

print(
    json.dumps(
        {
            "green": green,
            "spec_ok": spec_ok,
            "tasks_done": tasks_done,
            "attempt": attempt,
            "failures": "\n\n".join(failures),
        }
    )
)
