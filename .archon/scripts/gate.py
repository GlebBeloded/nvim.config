"""Test gate for one build iteration. A change with a `## Blocked` section (blocked.py, not only `loop:` items) is red at once
with `blocked` true: no make check and no review, since it never ships. Hard rules (integrity.py, then pinned.py on the proposal and branch diff) first: a violation is red at once, with
no make check and no review. When only the `test`, `test-readiness`, `stack`, `smoke-health` and e2e layers fail, each failing
case is rerun once, serially (e2e only when it failed on sandbox infra alone, with no `FAIL in` case: one
`make e2e E2E=1`): all passing (a test rerun must print its case as passed) makes the check green with them
listed as `flaky` (a note, not a finding). A case the branch adds or edits, or named after a scenario of the
change, never reruns: it stays red (other failing cases still rerun). An e2e rerun failing on sandbox infra again, with every other rerun
passing, prints `infra` (the sandbox line): the loop stops on it with no fix pass, and the pass is no attempt. A test case the previous pass had and that is now gone (on base neither:
verdict.py's case snapshot) is a hard rule, recorded for the judge. Planning files the fix pass edited (vs. the snapshot verdict.py took
at the pass's start) go to $ARTIFACTS_DIR/fix-scope.md for the review. Then the quick tier (check(): the touched capabilities' tests, no e2e) and, once it is green, the full make check E2E=1, strict OpenSpec
validation of the change and of the main specs after a trial archive, and tasks.md completion. Never fails the node: prints one JSON verdict so
the build loop can feed failures back to the next implement pass. Counts attempts in ARTIFACTS_DIR.
"""

import json
import os
import pathlib
import signal
import subprocess
import re
import sys

from blocked import blocked_text
from check_log import failed_targets, failing_cases, sections, strip_ansi, summarize
from integrity import BASE, commit_paths, staged, CASE_CHAIN, CASE_KEY, case_names, git, hard_rule_violations, plan_edits, record_dropped
from pinned import pinned
from scenarios import covered, untested
from spec_trial import archived_specs_ok as trial_archive
from sync_base import sync
from tasks import tick_gate_items, unchecked


change = os.environ.get("INPUTS_CHANGE", "")
artifacts = pathlib.Path(os.environ.get("ARTIFACTS_DIR", ".")).resolve()
counter = artifacts / "attempts"
attempt = int(counter.read_text()) + 1 if counter.exists() else 1
counter.write_text(str(attempt))


# gopls can take ~2 min to load a module on a busy host; tests read this via H.lsp_timeout (tests/helpers.lua)
LSP_TIMEOUT_MS = "120000"


# below the node's `timeout:` (nvim-deliver.yaml), so an overloaded host ends as `infra`, not a killed node
CHECK_TIMEOUT_S = int(os.environ.get("CHECK_TIMEOUT_S") or 2700)
TIMED_OUT = "check: TIMEOUT"


def run(cmd: list[str], log: str, timeout: int | None = None, extra: dict[str, str] | None = None) -> tuple[bool, str]:
    """Runs `cmd` writing its output to the log as it goes (a killed gate still leaves evidence); past
    `timeout` s the whole process group is killed and the output ends with a TIMED_OUT line."""
    env = {**os.environ, "LSP_TIMEOUT_MS": os.environ.get("LSP_TIMEOUT_MS") or LSP_TIMEOUT_MS, **(extra or {})}
    path = artifacts / log
    with path.open("w") as f:
        proc = subprocess.Popen(cmd, stdout=f, stderr=subprocess.STDOUT, text=True, env=env, start_new_session=True)
        try:
            code = proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(proc.pid, signal.SIGKILL)
            proc.wait()
            code = None
    out = strip_ansi(path.read_text())  # plain text, so `rg 'FAIL in'` finds every case
    if code is None:
        out += f"\n{TIMED_OUT} after {timeout} s (host overloaded or a hung test)\n"
    path.write_text(out)
    return code == 0, out


def tail(out: str) -> str:
    return "\n".join(out.splitlines()[-40:])


def archived_specs_ok(log: str) -> tuple[bool, str]:
    ok, out = trial_archive(change)
    (artifacts / log).write_text(out)
    return ok, tail(out)


def long_delta_requirements() -> str:
    """Names and lengths of this change's delta requirements over OpenSpec's 500-character limit."""
    lines = []
    for spec in sorted((pathlib.Path("openspec/changes") / change / "specs").glob("*/spec.md")):
        for block in re.split(r"(?m)^### Requirement:\s*", spec.read_text())[1:]:
            title, _, rest = block.partition("\n")
            text = re.split(r"(?m)^#### ", rest)[0].strip()
            if len(text) > 500:
                lines.append(f"- delta `{title.strip()}` ({spec}) is {len(text)} chars, limit 500")
    return ("\n" + "\n".join(lines)) if lines else ""


def hard_rules() -> list[str]:
    try:
        reasons = hard_rule_violations()
        # a case an earlier pass had (verdict's snapshot) and this pass removed; the judge rejects if it stays gone
        dropped = record_dropped(artifacts)
    except subprocess.CalledProcessError:  # not a git repo, or no base branch: nothing to compare
        reasons, dropped = [], []
    # instructable for the next fix pass; the judge still never ships while one stays gone (still_dropped)
    delta = f"openspec/changes/{change}/specs" if change else "the change's spec delta"
    remedy = f" (restore these cases under their names, or add a same-titled scenario to {delta}; never fold or rename them)"
    reasons += ["test added then removed during build: " + ", ".join(dropped) + remedy] if dropped else []
    # main-spec scenarios the proposal or the branch diff touches with no delta and no Impact line
    pins = pinned(change) if change else []
    reasons += [f"tests/flaky.txt gains a case on this branch (only the loop auditor adds one): {c}" for c in quarantined()]
    return reasons + [f"pinned scenario with no MODIFIED delta or Impact line: {p}" for p in pins]


def quarantined() -> list[str]:
    """Cases the branch adds to tests/flaky.txt: a change never quarantines its own failure."""
    try:
        diff = staged("diff", "--cached", "-U0", git("merge-base", "HEAD", BASE).strip(), "--", "tests/flaky.txt")
    except subprocess.CalledProcessError:
        return []
    return [line[1:].strip() for line in diff.splitlines() if line.startswith("+") and " | " in line and not line.startswith("+++")]


def record_fix_scope() -> None:
    """fix-scope.md lists the planning files edited since verdict's snapshot; absent when none were."""
    snapshot, scope = artifacts / "plan-snapshot.json", artifacts / "fix-scope.md"
    live = change and pathlib.Path("openspec/changes", change).is_dir()  # archived after the pass: nothing to compare
    edits = plan_edits(json.loads(snapshot.read_text()), change) if snapshot.exists() and live else []
    scope.unlink(missing_ok=True)
    if edits:
        scope.write_text("fix pass edited planning files (allowed only when a listed finding needs it): " + ", ".join(edits) + "\n")


def red(failures: str, blocked: bool = False, infra: str = "") -> None:
    out = {"green": False, "spec_ok": True, "tasks_done": True, "untested": 0, "attempt": attempt, "failures": failures, "flaky": []}
    out["infra"] = infra
    print(json.dumps({**out, "blocked": blocked}))
    sys.exit(0)


if os.environ.get("INPUTS_SYNC_BASE") == "true":  # the base moved since the fork (its fixes, approved renders)
    print(sync() or "sync: base already merged", file=sys.stderr)
blocked = blocked_text(change)
if blocked:  # the next pass settles it (unblock.md), so checking or reviewing it is wasted; no attempt either
    counter.write_text(str(attempt - 1))
    red("blocked: " + blocked, blocked=True)
record_fix_scope()
violations = hard_rules()
if violations:  # never shipped: a full make check and a review would be wasted on it
    red("\n".join(f"hard rule: {v}" for v in violations))

# e2e lines of a VM that never answered (sandbox.sh, Lume, make): the e2e layer did not run, nothing it tests failed
INFRA_LINE = re.compile(r"^(sandbox: |Error: VM |\[[\dT:.Z-]+\] [A-Z]+: |make(\[\d+\])?: \*\*\* )")
INFRA = re.compile(r"did not answer|not running|stopped while booting|lost track of|no GUI session|while it unpacks")


def e2e_infra(body: list[str]) -> str:
    """The infra reason of an e2e section with no `FAIL in` case and only sandbox lines; empty otherwise."""
    lines = [line.strip() for line in body if line.strip()]
    if failing_cases(lines) or not all(INFRA_LINE.match(line) for line in lines):
        return ""
    known = next((line for line in reversed(lines) if INFRA.search(line)), "")  # the last: sandbox.sh dies on it
    # no case ran and only sandbox lines: still the host's failure, named by its last sandbox line (run 8ce36755:
    # "has a lume run process while Lume reports it ; waiting for it", then make's error, nothing else)
    return known or next((line for line in reversed(lines) if line.startswith(("sandbox: ", "Error: VM "))), "")


STATUS = re.compile(r": (hung: no progress for \d+ s .*|not run: its worker was killed after a hung case)$")


def case_name(file: str, label: str) -> str:
    """The case of a `FAIL in` label as `CASE=` takes it: its set chain (`<set> | <case>` in a nested set),
    with no ` + args …` (a parametrized set) and no error message after it (`<name>: <message>`, e.g. a
    readiness bound): the longest case of `file` the last part starts with, else the label itself."""
    label = re.sub(r" \+ args .*", "", label)
    label = STATUS.sub("", label)  # tests/parallel.lua's hung/not-run note, kept when the case is not parsed (`T[var][...]`)
    *sets, last = label.split(" | ")
    try:
        names = case_names(pathlib.Path(file).read_text())
    except OSError:
        return label
    matches = [n for n in names if last == n or last.startswith(n + ":")]
    return " | ".join([*sets, max(matches, key=len)]) if matches else label


def branch_cases() -> dict[str, set[str]]:
    """Per test file the branch changes against its base (committed or not), the cases whose `T[...]` line
    or body it adds or edits: the case each changed line of the file falls under."""
    try:
        git("add", "-A")
        out = git("diff", "--cached", "-U0", git("merge-base", "HEAD", BASE).strip(), "--", "tests/")
    except subprocess.CalledProcessError:  # not a git repo, or no base branch
        return {}
    owned: dict[str, set[str]] = {}
    for chunk in re.split(r"(?m)^diff --git ", out)[1:]:
        path = re.search(r"(?m)^\+\+\+ b/(.+)$", chunk)
        if not path or not os.path.isfile(path.group(1)):
            continue
        text = pathlib.Path(path.group(1)).read_text(errors="replace").splitlines()
        starts = [(n, CASE_KEY.findall(m.group(1))[-1]) for n, l in enumerate(text, 1) if (m := CASE_CHAIN.match(l))]
        names = owned.setdefault(path.group(1), set())
        for start, count in re.findall(r"(?m)^@@ -\S+ \+(\d+)(?:,(\d+))? @@", chunk):
            for n in range(int(start), int(start) + max(int(count or 1), 1)):  # `+c,0`: lines removed after c
                names.update([name for line, name in starts if line <= n][-1:])
    return owned


def rerun_plan(out: str) -> tuple[list[tuple[str, list[str]]], list[str]]:
    """(case, rerun command) for every failure of a check whose failed targets all rerun, else none, and the
    failures the change owns: a case it adds or edits (branch_cases) or one named after a scenario of the
    change never reruns (its failure is the change's, not a flake); other cases, in its files too, still do."""
    targets, bodies = failed_targets(out), dict(sections(out.splitlines()))
    changed, scenarios = None, set(covered(change_dir)) if change and change_dir.is_dir() else set()
    plan: list[tuple[str, list[str]]] = []
    owned: list[str] = []
    for target in targets:
        body = bodies.get(target, [])
        if target == "e2e":
            reason = e2e_infra(body)
            if not reason:
                return [], []
            plan.append((f"e2e: {reason}", ["make", "e2e", "E2E=1"]))
            continue
        if target == "smoke-health":  # one target run (~15 s): an error the change causes fails again
            error = next((line.strip() for line in body if "ERROR" in line and not line.startswith("FAIL")), "checkhealth")
            plan.append((f"smoke-health: {error}", ["make", "smoke-health"]))
            continue
        if target == "stack":  # real zellij + Neovim (~20 s) timing out under a parallel drain's load: one target rerun
            failed = next((line.strip() for line in body if line.startswith("FAIL in")), "stack")
            plan.append((f"stack: {failed}", ["make", "stack"]))
            continue
        cases = failing_cases(body)
        if target not in ("test", "test-readiness") or not cases or any(" | " not in c for c in cases):
            return [], []
        for case in cases:
            file, name = case.split(" | ", 1)
            name = case_name(file, name)
            changed = branch_cases() if changed is None else changed
            last = name.split(" | ")[-1]
            if last in changed.get(file, set()) or last in scenarios:
                owned.append(case)
                continue
            narrow = [f"CASE={name}"] if target == "test-readiness" else [f"FILE={file}", f"CASE={name}"]
            plan.append((case, ["make", target, *narrow]))
    return plan, owned


def rerun_passed(case: str, cmd: list[str], ok: bool, out: str) -> bool:
    """A rerun exited 0 and, for a test case, printed its group as all passed: the reporter groups by file
    and top-level set (group_depth 2), `<file> | <case>: o`, or `<file> | <set>: oo` for a nested set."""
    if not ok or case.startswith(("e2e: ", "smoke-health: ", "stack: ")):  # whole-target reruns: the exit code says it
        return ok
    file, group = case.split(" | ", 1)[0], cmd[-1].removeprefix("CASE=").split(" | ")[0]
    prefix = f"{file} | {group}: "
    return any(line.startswith(prefix) and re.fullmatch("o+", line[len(prefix) :]) for line in out.splitlines())


KNOWN_RERUNS = 3


def known_flaky() -> list[str]:
    """The `<file> | <case>` lines of tests/flaky.txt: known timing-sensitive cases, rerun up to KNOWN_RERUNS times."""
    try:
        lines = pathlib.Path("tests/flaky.txt").read_text().splitlines()
    except OSError:
        return []
    return [line.strip() for line in lines if " | " in line and not line.lstrip().startswith("#")]


def rerun_flaky(out: str, log: str) -> tuple[list[str], str, list[str]]:
    """(flaky cases, infra reason, owned failures) of a check whose failed targets all rerun (rerun_plan):
    the cases when each passes on one serial rerun (up to KNOWN_RERUNS for a tests/flaky.txt case); the sandbox line when e2e fails on infra again and every
    other rerun passes; otherwise neither. Reruns are appended to `log`."""
    (plan, owned), infra = rerun_plan(out), ""
    known = known_flaky()
    for index, (case, cmd) in enumerate(plan):
        tries = KNOWN_RERUNS if any(case == k or case.startswith(k + ":") or case.startswith(k + " | ") for k in known) else 1
        for n in range(tries):
            ok, rerun_out = run(cmd, f"rerun-{attempt}-{index + 1}.log")
            ok = rerun_passed(case, cmd, ok, rerun_out)
            label = f" ({n + 1}/{tries}, known flaky)" if tries > 1 else ""
            with (artifacts / log).open("a") as f:
                f.write(f"\n===== rerun {case}{label}: {'ok' if ok else 'FAIL'} =====\n{tail(rerun_out)}\n")
            if ok:
                break
        if not ok and not (case.startswith("e2e: ") and (infra := e2e_infra(rerun_out.splitlines()))):
            return [], "", owned
    if infra:  # with an owned failure the pass is the change's to fix, not the host's
        return [], "" if owned else infra, owned
    cases = [case for case, _ in plan]
    if cases:
        with (artifacts / log).open("a") as f:
            f.write("\nflaky (failed, then passed on rerun): " + ", ".join(cases) + "\n")
    return cases, "", owned


TEST_LAYERS = ("unit", "integration", "screen")
QUICK_TARGETS = "lint types trace specs test"
# every test depends on these: a change to one runs the whole quick tier
SHARED = {"tests/helpers.lua", "tests/minimal_init.lua", "tests/child_init.lua", "tests/runner.lua", "tests/parallel.lua", "init.lua", "Makefile"}
SHARED_DIRS = ("lua/gleb/plugins/", "settings/", "lua/gleb/util/")  # every area's plugin specs, keymaps, helpers
# paths only the full check tests (the sandbox VM, smoke, the terminal configs): a quick tier would prove nothing
FULL_ONLY = re.compile(r"^(tests/(sandbox|smoke)/|terminal/)")
# the shortcut layers run in the full check only; their files still name the capability they cover
SHORTCUT_LAYERS = ("e2e", "chain", "stack", "shortcuts")


def referencing_caps(path: str, known: set[str]) -> set[str]:
    """Capabilities whose test files name `path`: its module (`tests.fixtures.gh.mutations`, `gleb.alpha`), its folder's
    module, or its repo path without `.lua`. A support file maps to the tests that use it, not to every test (pr
    gates fell back to the whole suite for one fixture, Oct 2026)."""
    stem = path.removesuffix(".lua").removesuffix("/init")
    module = stem.removeprefix("lua/").replace("/", ".")
    needles = {module, stem.removeprefix("tests/"), module.rsplit(".", 1)[0]} - {"tests", "gleb", ""}
    caps = set()
    for layer in TEST_LAYERS:
        for test in pathlib.Path("tests", layer).glob("*/**/*.lua"):
            cap = test.parts[2]
            if cap in known and cap not in caps and any(n in test.read_text(errors="replace") for n in needles):
                caps.add(cap)
    return caps


def test_caps() -> set[str]:
    return {d.name for layer in TEST_LAYERS for d in pathlib.Path("tests", layer).glob("*") if d.is_dir()}


def affected() -> tuple[str, bool] | None:
    """(CAPS, loop) of the quick tier for the branch diff against its base (committed or not): the capability of
    each `lua/gleb/<area>` and `tests/<layer>/<cap>` path (shortcut layers included), of the tests naming any
    other file (referencing_caps), `loop` and loop-test for `.archon/`; "" (every capability) for a SHARED file or
    one no test names; None when no quick tier applies: nothing to test (planning and docs only) or a path only
    the full check tests."""
    try:
        git("add", "-A")
        paths = git("diff", "--cached", "--name-only", git("merge-base", "HEAD", BASE).strip()).split()
    except subprocess.CalledProcessError:
        return None
    caps, loop, every = set(), False, False
    known = test_caps()
    for path in paths:
        parts = path.split("/")
        if FULL_ONLY.match(path):
            return None
        if path.startswith(("openspec/", "docs/")) or path.endswith(".md"):
            continue
        if path.startswith(".archon/"):
            caps.add("loop")
            loop = True
            continue
        if len(parts) > 3 and parts[0] == "tests" and parts[1] in TEST_LAYERS + SHORTCUT_LAYERS:
            caps.update({parts[2]} & known)  # a shortcut-layer file: its capability's quick tests, the layer in the full check
            continue
        if len(parts) > 2 and parts[:2] == ["lua", "gleb"]:
            area = parts[2].removesuffix(".lua").replace("_", "-")
            if area in known and area != "plugins":  # lua/gleb/plugins holds every area's plugin specs
                caps.add(area)
                continue
        # a shared file (tests/helpers.lua, init.lua, settings) has no single owner; a support file maps by its users
        found = set() if path in SHARED or path.startswith(SHARED_DIRS) else referencing_caps(path, known)
        caps |= found
        every = every or not found
    if not caps and not every:
        return None
    return ("" if every else ",".join(sorted(caps))), loop


def timed_out(out: str, log: str) -> None:
    if TIMED_OUT in out:  # not the change's failure: no fix pass, no attempt; the loop stops as infra
        counter.write_text(str(attempt - 1))
        red(f"infra: make check timed out after {CHECK_TIMEOUT_S} s\nfull log: {artifacts / log}", infra="check timed out")


def checked(cmd: list[str], log: str, extra: dict[str, str] | None = None, note: str = "") -> tuple[bool, str, list[str], list[str]]:
    """(green, output, flaky, owned) of one check run and its reruns (rerun_flaky); infra ends the gate."""
    green, out = run(cmd, log, CHECK_TIMEOUT_S, extra)
    if note:
        out = note + out
        (artifacts / log).write_text(out)
    timed_out(out, log)
    flaky, infra, owned = ([], "", []) if green else rerun_flaky(out, log)
    if infra:  # the host failed twice, not the change: the loop stops with no fix pass, and this pass is no attempt
        counter.write_text(str(attempt - 1))
        red(f"infra: e2e did not run (sandbox failed twice): {infra}\nfull log: {artifacts / log}", infra=infra)
    return green or (bool(flaky) and not owned), out, flaky, owned


def check() -> tuple[bool, str, list[str], list[str]]:
    """(green, output, flaky, owned) of the gate's check, its log `check-<attempt>.log`. A gate first runs the
    quick tier on the capabilities the branch touches (`affected`: lint, types, trace, specs, their tests,
    loop-test for loop files; no e2e): red ends the gate there, and only a green quick tier (kept as
    `quick-<attempt>.log`) runs the full `make check E2E=1`."""
    log, quick_flaky = f"check-{attempt}.log", []
    tier = affected()
    if tier is not None:
        caps, loop = tier
        targets = QUICK_TARGETS + (" loop-test" if loop else "")
        note = f"quick tier: {targets} with CAPS={caps or '(all)'}; the full make check E2E=1 runs once it is green\n"
        cmd = ["make", "check", f"CHECK_TARGETS={targets}"]
        green, out, quick_flaky, owned = checked(cmd, log, {"CAPS": caps}, note)
        if not green:
            return green, out, quick_flaky, owned
        (artifacts / log).rename(artifacts / f"quick-{attempt}.log")
    # E2E=1: e2e runs in the sandbox VM and boots it when it is down (docs/testing.md, Sandbox VM)
    green, out, flaky, owned = checked(["make", "check", "E2E=1"], log)
    return green, out, quick_flaky + [f for f in flaky if f not in quick_flaky], owned


change_dir = pathlib.Path("openspec/changes") / change
check_log = f"check-{attempt}.log"
green, check_out, flaky, owned = check()
spec_ok, spec_tail = True, ""
tasks_done = True
if change and change_dir.is_dir():
    spec_ok, spec_out = run(["openspec", "validate", change, "--strict", "--no-interactive"], f"validate-{attempt}.log")
    spec_tail = tail(spec_out)
    if spec_ok:
        spec_ok, spec_tail = archived_specs_ok(f"archive-{attempt}.log")
    missing = untested(covered(change_dir))
    tasks = change_dir / "tasks.md"
    if green and tasks.exists():
        ticked = tick_gate_items(tasks.read_text())
        if ticked != tasks.read_text():
            tasks.write_text(ticked)
            commit_paths(f"chore(openspec): tick gate items of {change}", str(tasks))
    tasks_done = tasks.exists() and unchecked(tasks.read_text()) == 0

missing = missing if change and change_dir.is_dir() else []
failures = []
if missing:
    failures.append("scenarios of this change with no test named after them:\n" + "\n".join("- " + m for m in missing))
if not green:
    failures.append("make check is red:\n" + summarize(check_out, str(artifacts / check_log)))
    if owned and flaky:
        failures.append("passed on rerun (flaky, not this change's): " + ", ".join(flaky))
        flaky = []
if not spec_ok:
    failures.append(
        "openspec validate --strict (change, or main specs after a trial archive) failed; reproduce with "
        f"`python3 .archon/scripts/spec_trial.py {change}` (a green `openspec validate --specs` on the unarchived "
        "main specs does not count):\n" + spec_tail + long_delta_requirements()
    )
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
            "infra": "",
            "blocked": False,
        }
    )
)
