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

from tasks import unchecked

change = os.environ.get("INPUTS_CHANGE", "")
artifacts = pathlib.Path(os.environ.get("ARTIFACTS_DIR", ".")).resolve()
counter = artifacts / "attempts"
attempt = int(counter.read_text()) + 1 if counter.exists() else 1
counter.write_text(str(attempt))


def run(cmd: list[str], log: str) -> tuple[bool, str]:
    proc = subprocess.run(cmd, capture_output=True, text=True)
    out = proc.stdout + proc.stderr
    (artifacts / log).write_text(out)
    return proc.returncode == 0, "\n".join(out.splitlines()[-40:])


def archived_specs_ok(log: str) -> tuple[bool, str]:
    """Archive the change in a scratch copy of openspec/ and validate the resulting main specs, so a
    delta that breaks `openspec validate --specs --strict` (e.g. an overlong requirement) is caught
    here, where the next pass can fix it, instead of after ship's real archive."""
    with tempfile.TemporaryDirectory() as tmp:
        shutil.copytree("openspec", pathlib.Path(tmp) / "openspec")
        cwd = os.getcwd()
        os.chdir(tmp)
        try:
            ok, tail = run(["openspec", "archive", change, "--yes"], log)
            if ok:
                ok, tail = run(["openspec", "validate", "--specs", "--strict", "--no-interactive"], log)
        finally:
            os.chdir(cwd)
    return ok, tail


# E2E=1: e2e runs in the sandbox VM and boots it when it is down (docs/testing.md, Sandbox VM)
green, check_tail = run(["make", "check", "E2E=1"], f"check-{attempt}.log")
spec_ok, spec_tail = True, ""
tasks_done = True
change_dir = pathlib.Path("openspec/changes") / change
if change and change_dir.is_dir():
    spec_ok, spec_tail = run(["openspec", "validate", change, "--strict", "--no-interactive"], f"validate-{attempt}.log")
    if spec_ok:
        spec_ok, spec_tail = archived_specs_ok(f"archive-{attempt}.log")
    tasks = change_dir / "tasks.md"
    tasks_done = tasks.exists() and unchecked(tasks.read_text()) == 0

failures = []
if not green:
    failures.append("make check is red:\n" + check_tail)
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
            "attempt": attempt,
            "failures": "\n\n".join(failures),
        }
    )
)
