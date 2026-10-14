"""Test gate for one build iteration. A change with a `## Blocked` section (blocked.py, not only `loop:` items) is red at once
with `blocked` true: no make check and no review, since it never ships. Hard rules (integrity.py, then pinned.py on the proposal and branch diff) first: a violation is red at once, with
no make check and no review. When only the `test`, `test-readiness` and e2e layers fail, each failing
case is rerun once, serially (e2e only when it failed on sandbox infra alone, with no `FAIL in` case: one
`make e2e E2E=1`): all passing makes the check green with them listed as `flaky` (a note, not a finding). A test case the previous pass had and that is now gone (on base neither:
verdict.py's case snapshot) is a hard rule, recorded for the judge. Planning files the fix pass edited (vs. the snapshot verdict.py took
at the pass's start) go to $ARTIFACTS_DIR/fix-scope.md for the review. Then make check (lint, types, tests, smoke, trace), strict OpenSpec
validation of the change and of the main specs after a trial archive, and tasks.md completion. Never fails the node: prints one JSON verdict so
the build loop can feed failures back to the next implement pass. Counts attempts in ARTIFACTS_DIR.
"""

import json
import os
import pathlib
import subprocess
import re
import sys

from blocked import blocked_text
from check_log import failed_targets, failing_cases, sections, strip_ansi, summarize
from integrity import hard_rule_violations, plan_edits, record_dropped
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
        # a case an earlier pass had (verdict's snapshot) and this pass removed; the judge asks if it stays gone
        dropped = record_dropped(artifacts)
    except subprocess.CalledProcessError:  # not a git repo, or no base branch: nothing to compare
        reasons, dropped = [], []
    reasons += ["test added then removed during build: " + ", ".join(dropped)] if dropped else []
    # main-spec scenarios the proposal or the branch diff touches with no delta and no Impact line
    pins = pinned(change) if change else []
    return reasons + [f"pinned scenario with no MODIFIED delta or Impact line: {p}" for p in pins]


def record_fix_scope() -> None:
    """fix-scope.md lists the planning files edited since verdict's snapshot; absent when none were."""
    snapshot, scope = artifacts / "plan-snapshot.json", artifacts / "fix-scope.md"
    live = change and pathlib.Path("openspec/changes", change).is_dir()  # archived after the pass: nothing to compare
    edits = plan_edits(json.loads(snapshot.read_text()), change) if snapshot.exists() and live else []
    scope.unlink(missing_ok=True)
    if edits:
        scope.write_text("fix pass edited planning files (allowed only when a listed finding needs it): " + ", ".join(edits) + "\n")


def red(failures: str, blocked: bool = False) -> None:
    out = {"green": False, "spec_ok": True, "tasks_done": True, "untested": 0, "attempt": attempt, "failures": failures, "flaky": []}
    print(json.dumps({**out, "blocked": blocked}))
    sys.exit(0)


blocked = blocked_text(change)
if blocked:  # verdict ends the loop on it and the judge asks: checking or reviewing it is wasted
    red("blocked: " + blocked, blocked=True)
record_fix_scope()
violations = hard_rules()
if violations:  # never shipped: a full make check and a review would be wasted on it
    red("\n".join(f"hard rule: {v}" for v in violations))

# e2e lines of a VM that never answered (sandbox.sh, Lume, make): the e2e layer did not run, nothing it tests failed
INFRA_LINE = re.compile(r"^(sandbox: |Error: VM |\[[\dT:.Z-]+\] [A-Z]+: |make(\[\d+\])?: \*\*\* )")
INFRA = re.compile(r"did not answer|not running|stopped while booting|lost track of|no GUI session")


def e2e_infra(body: list[str]) -> str:
    """The infra reason of an e2e section with no `FAIL in` case and only sandbox lines; empty otherwise."""
    lines = [line.strip() for line in body if line.strip()]
    if failing_cases(lines) or not all(INFRA_LINE.match(line) for line in lines):
        return ""
    return next((line for line in reversed(lines) if INFRA.search(line)), "")  # the last: sandbox.sh dies on it


def rerun_plan(out: str) -> list[tuple[str, list[str]]]:
    """(case, rerun command) for every failure of a check whose failed targets all rerun; else none."""
    targets, bodies = failed_targets(out), dict(sections(out.splitlines()))
    plan: list[tuple[str, list[str]]] = []
    for target in targets:
        body = bodies.get(target, [])
        if target == "e2e":
            reason = e2e_infra(body)
            if not reason:
                return []
            plan.append((f"e2e: {reason}", ["make", "e2e", "E2E=1"]))
            continue
        cases = failing_cases(body)
        if target not in ("test", "test-readiness") or not cases or any(" | " not in c for c in cases):
            return []
        for case in cases:
            file, name = case.split(" | ", 1)
            narrow = [f"CASE={name}"] if target == "test-readiness" else [f"FILE={file}", f"CASE={name}"]
            plan.append((case, ["make", target, *narrow]))
    return plan


def rerun_flaky(out: str, log: str) -> list[str]:
    """The failures of a check whose failed targets all rerun (rerun_plan), if each passes on one serial
    rerun; otherwise none. Reruns are appended to `log`."""
    plan = rerun_plan(out)
    for index, (case, cmd) in enumerate(plan):
        ok, rerun_out = run(cmd, f"rerun-{attempt}-{index + 1}.log")
        with (artifacts / log).open("a") as f:
            f.write(f"\n===== rerun {case}: {'ok' if ok else 'FAIL'} =====\n{tail(rerun_out)}\n")
        if not ok:
            return []
    cases = [case for case, _ in plan]
    if cases:
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
            "blocked": False,
        }
    )
)
