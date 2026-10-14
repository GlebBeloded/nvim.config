"""Test gate for one build iteration. Hard rules (integrity.py, then pinned.py on the proposal and branch diff) first: a violation is red at once, with
no make check and no review. When only the `test` layer fails, each failing case is rerun once,
serially: all passing makes the check green with them listed as `flaky` (a note, not a finding). Planning files the fix pass edited (vs. the snapshot verdict.py took
at the pass's start) go to $ARTIFACTS_DIR/fix-scope.md for the review. Then make check (lint, types, tests, smoke, trace), strict OpenSpec
validation of the change and of the main specs after a trial archive, and tasks.md completion. Never fails the node: prints one JSON verdict so
the build loop can feed failures back to the next implement pass. Counts attempts in ARTIFACTS_DIR.
"""

import json
import os
import pathlib
import subprocess
import sys

from check_log import failed_targets, failing_cases, strip_ansi, summarize
from integrity import hard_rule_violations, plan_edits
from pinned import pinned
from scenarios import covered, untested
from spec_trial import archived_specs_ok as trial_archive
from tasks import tick_gate_items, unchecked


change = os.environ.get("INPUTS_CHANGE", "")
artifacts = pathlib.Path(os.environ.get("ARTIFACTS_DIR", ".")).resolve()
counter = artifacts / "attempts"
attempt = int(counter.read_text()) + 1 if counter.exists() else 1
counter.write_text(str(attempt))


# gopls can take ~2 min to load a module on a busy host; tests read this via H.lsp_timeout (tests/helpers.lua)
LSP_TIMEOUT_MS = "120000"


def run(cmd: list[str], log: str) -> tuple[bool, str]:
    env = {**os.environ, "LSP_TIMEOUT_MS": os.environ.get("LSP_TIMEOUT_MS") or LSP_TIMEOUT_MS}
    proc = subprocess.run(cmd, capture_output=True, text=True, env=env)
    out = strip_ansi(proc.stdout + proc.stderr)  # plain text, so `rg 'FAIL in'` finds every case
    (artifacts / log).write_text(out)
    return proc.returncode == 0, out


def tail(out: str) -> str:
    return "\n".join(out.splitlines()[-40:])


def archived_specs_ok(log: str) -> tuple[bool, str]:
    ok, out = trial_archive(change)
    (artifacts / log).write_text(out)
    return ok, tail(out)


def hard_rules() -> list[str]:
    try:
        reasons = hard_rule_violations()
    except subprocess.CalledProcessError:  # not a git repo, or no base branch: nothing to compare
        reasons = []
    # main-spec scenarios the proposal or the branch diff touches with no delta and no Impact line
    pins = pinned(change) if change else []
    return reasons + [f"pinned scenario with no MODIFIED delta or Impact line: {p}" for p in pins]


def record_fix_scope() -> None:
    """fix-scope.md lists the planning files edited since verdict's snapshot; absent when none were."""
    snapshot, scope = artifacts / "plan-snapshot.json", artifacts / "fix-scope.md"
    edits = plan_edits(json.loads(snapshot.read_text()), change) if snapshot.exists() and change else []
    scope.unlink(missing_ok=True)
    if edits:
        scope.write_text("fix pass edited planning files (allowed only when a listed finding needs it): " + ", ".join(edits) + "\n")


def red(failures: str) -> None:
    out = {"green": False, "spec_ok": True, "tasks_done": True, "untested": 0, "attempt": attempt, "failures": failures, "flaky": []}
    print(json.dumps(out))
    sys.exit(0)


record_fix_scope()
violations = hard_rules()
if violations:  # never shipped: a full make check and a review would be wasted on it
    red("\n".join(f"hard rule: {v}" for v in violations))

def rerun_flaky(out: str, log: str) -> list[str]:
    """The failing cases of a check where only the `test` layer failed, if each passes on one serial
    rerun (`make test FILE=<file> CASE=<name>`); otherwise none. Reruns are appended to `log`."""
    cases = failing_cases(out.splitlines())
    if failed_targets(out) != ["test"] or not cases or any(" | " not in c for c in cases):
        return []
    for index, case in enumerate(cases):
        file, name = case.split(" | ", 1)
        ok, rerun_out = run(["make", "test", f"FILE={file}", f"CASE={name}"], f"rerun-{attempt}-{index + 1}.log")
        with (artifacts / log).open("a") as f:
            f.write(f"\n===== rerun {case}: {'ok' if ok else 'FAIL'} =====\n{tail(rerun_out)}\n")
        if not ok:
            return []
    with (artifacts / log).open("a") as f:
        f.write("\nflaky (failed, then passed on rerun): " + ", ".join(cases) + "\n")
    return cases


# E2E=1: e2e runs in the sandbox VM and boots it when it is down (docs/testing.md, Sandbox VM)
check_log = f"check-{attempt}.log"
green, check_out = run(["make", "check", "E2E=1"], check_log)
flaky = [] if green else rerun_flaky(check_out, check_log)
green = green or bool(flaky)
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
            "flaky": flaky,
        }
    )
)
