"""Test gate for one build iteration: make check (lint, types, tests, smoke, trace), strict OpenSpec
validation of the change and of the main specs after a trial archive, and tasks.md completion. Never fails the node: prints one JSON verdict so
the build loop can feed failures back to the next implement pass. Counts attempts in ARTIFACTS_DIR.
"""

import json
import os
import pathlib
import shutil
import subprocess
import tempfile

from check_log import strip_ansi, summarize
from scenarios import covered, untested
from spec_trial import archived_specs_ok as trial_archive
from tasks import tick_gate_items, unchecked


change = os.environ.get("INPUTS_CHANGE", "")
artifacts = pathlib.Path(os.environ.get("ARTIFACTS_DIR", ".")).resolve()
counter = artifacts / "attempts"
attempt = int(counter.read_text()) + 1 if counter.exists() else 1
counter.write_text(str(attempt))


def run(cmd: list[str], log: str) -> tuple[bool, str]:
    proc = subprocess.run(cmd, capture_output=True, text=True)
    out = strip_ansi(proc.stdout + proc.stderr)  # plain text, so `rg 'FAIL in'` finds every case
    (artifacts / log).write_text(out)
    return proc.returncode == 0, out


def tail(out: str) -> str:
    return "\n".join(out.splitlines()[-40:])


def archived_specs_ok(log: str) -> tuple[bool, str]:
    ok, out = trial_archive(change)
    (artifacts / log).write_text(out)
    return ok, tail(out)


# E2E=1: e2e runs in the sandbox VM and boots it when it is down (docs/testing.md, Sandbox VM)
check_log = f"check-{attempt}.log"
green, check_out = run(["make", "check", "E2E=1"], check_log)
spec_ok, spec_tail = True, ""
tasks_done = True
change_dir = pathlib.Path("openspec/changes") / change
if change and change_dir.is_dir():
    spec_ok, spec_out = run(["openspec", "validate", change, "--strict", "--no-interactive"], f"validate-{attempt}.log")
    spec_tail = tail(spec_out)
    if spec_ok:
        spec_ok, spec_tail = archived_specs_ok(f"archive-{attempt}.log")
    missing = untested(covered(change_dir))
    tasks = change_dir / "tasks.md"
    if green and tasks.exists():
        tasks.write_text(tick_gate_items(tasks.read_text()))
    tasks_done = tasks.exists() and unchecked(tasks.read_text()) == 0

missing = missing if change and change_dir.is_dir() else []
failures = []
if missing:
    failures.append("scenarios of this change with no test named after them:\n" + "\n".join("- " + m for m in missing))
if not green:
    failures.append("make check is red:\n" + summarize(check_out, str(artifacts / check_log)))
if not spec_ok:
    failures.append("openspec validate --strict (change, or main specs after a trial archive) failed:\n" + spec_tail)
if not tasks_done:
    failures.append(f"openspec/changes/{change}/tasks.md has unchecked tasks")

print(
    json.dumps(
        {
            "green": green,
            "spec_ok": spec_ok,
            "tasks_done": tasks_done,
            "untested": len(missing),
            "attempt": attempt,
            "failures": "\n\n".join(failures),
        }
    )
)
