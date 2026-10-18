"""Deterministic checks on the branch diff against its merge-base with `auto`, split by who decides:
`hard_rule_violations` (never shipped: the build loop fixes them, the judge rejects them) and
`breaking_changes` (the only reasons the user is asked, docs/workflow.md, Gates).
"""

import difflib
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import tempfile

BASE = os.environ.get("BASE_BRANCH") or "auto"
PLUGIN_NAME = re.compile(r'"([\w.-]+/[\w.-]+)"')
CASE_CHAIN = re.compile(r'^\s*T((?:\["[^"]+"\])+)')
CASE_KEY = re.compile(r'\["([^"]+)"\]')
SPEC_HEADER = re.compile(r"^diff --git a/openspec/specs/([^/]+)/spec\.md b/openspec/specs/([^/]+)/spec\.md$")
SCENARIO = re.compile(r"^#### Scenario:\s*(.+?)\s*$")
XFAIL_RE = re.compile(r'H\.xfail\(\s*"([\w.-]+)')
XFAIL_ARG = re.compile(r'H\.xfail\(\s*(?:"([\w.-]+)|([A-Za-z_]\w*))')  # a literal reason, or a local holding it
LOCAL_STRING = re.compile(r'^\s*local\s+([A-Za-z_]\w*)\s*=\s*"([^"]*)"', re.MULTILINE)
DELTA_SECTION = re.compile(r"^## (ADDED|MODIFIED|REMOVED|RENAMED) Requirements\s*$", re.MULTILINE)
REQUIREMENT = re.compile(r"^### Requirement:\s*(.+?)\s*$", re.MULTILINE)
DECISION = re.compile(r"^## Decision\b.*?(?=^## |\Z)", re.MULTILINE | re.DOTALL)
NEAR_NAME = 0.8  # difflib ratio at which a re-ADDED requirement counts as the REMOVED one


def git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout


def lines(diff: str, sign: str) -> list[str]:
    return [l[1:] for l in diff.splitlines() if l.startswith(sign) and not l.startswith(sign * 3)]


_INDEX: dict[str, str] = {}


def staged(*args: str, check: bool = True) -> str:
    """`git <args>` against a private copy of the index with everything staged (ship commits everything, so new
    files count). Staging into the real index made the agent's later `git add <touched files>` commit stray files;
    gate.py imports this module, so the process environment stays untouched. Staged once per working directory and
    process (a check reads the tree, never edits it): re-staging on every read doubled the judge's git calls (73,
    ~7 s at load 30), and it outran the 30 s test timeout under load."""
    root = os.getcwd()
    env = {**os.environ, "GIT_INDEX_FILE": _INDEX.get(root, "")}
    if root not in _INDEX:
        index = pathlib.Path(git("rev-parse", "--path-format=absolute", "--git-path", "index").strip())
        copy = pathlib.Path(tempfile.mkdtemp(prefix="integrity-")) / "index"
        if index.is_file():
            shutil.copy2(index, copy)  # keep its mtime: git re-hashes files changed in the index's own second (racy git)
        _INDEX[root] = str(copy)
        env["GIT_INDEX_FILE"] = str(copy)
        subprocess.run(["git", "add", "-A"], capture_output=True, text=True, check=True, env=env)
    return subprocess.run(["git", *args], capture_output=True, text=True, check=check, env=env).stdout


def diff(*paths: str) -> str:
    base = git("merge-base", "HEAD", BASE).strip()
    return staged("diff", "--cached", base, "--", *paths)


def changed_files(pattern: str) -> list[str]:
    """Active-change files matching `pattern` that the branch changed and that still exist."""
    base = git("merge-base", "HEAD", BASE).strip()
    names = staged("diff", "--cached", "--name-only", base, "--", "openspec/changes").split()
    return [n for n in names if re.fullmatch(pattern, n) and "/archive/" not in n and os.path.isfile(n)]


def net(removed: set[str], added: set[str]) -> tuple[set[str], set[str]]:
    """Identities only on one side of a diff: a moved or reordered line is neither removed nor added."""
    return removed - added, added - removed


def test_cases() -> tuple[set[str], set[str]]:
    """Removed and added mini.test case names (the last key of a `T["..."]["..."]` chain)."""
    tests = diff("tests/")
    removed = {CASE_KEY.findall(m.group(1))[-1] for l in lines(tests, "-") if (m := CASE_CHAIN.match(l))}
    added = {CASE_KEY.findall(m.group(1))[-1] for l in lines(tests, "+") if (m := CASE_CHAIN.match(l))}
    return net(removed, added)


def scenarios() -> tuple[set[str], set[str]]:
    """Removed and added main-spec scenarios as `<capability>: <title>`, the names tests use."""
    removed: set[str] = set()
    added: set[str] = set()
    old = new = None
    for line in diff("openspec/specs").splitlines():
        if line.startswith("diff --git "):
            header = SPEC_HEADER.match(line)
            old, new = header.groups() if header else (None, None)
            continue
        title = SCENARIO.match(line[1:]) if old and line[:1] in "+-" and not line.startswith(("+++", "---")) else None
        if title:
            (removed if line[0] == "-" else added).add(f"{old if line[0] == '-' else new}: {title.group(1)}")
    return net(removed, added)


def capability_renames() -> dict[str, str]:
    """Old to new capability for each main spec Git sees renamed (`openspec/specs/<capability>/spec.md`)."""
    base = git("merge-base", "HEAD", BASE).strip()
    rows = staged("diff", "--cached", "-M", "--name-status", base, "--", "openspec/specs").splitlines()
    renames = {}
    for row in rows:
        status, *paths = row.split("\t")
        if status.startswith("R") and len(paths) == 2:
            old, new = (p.split("/") for p in paths)
            if len(old) == len(new) == 4:
                renames[old[2]] = new[2]
    return renames


class Coverage:
    """Scenario and test-case changes of the branch, with tested renames paired off: a removed scenario
    is renamed when an added scenario of the same (or renamed) capability is too, the old case name is
    removed and the new one added, one for one. A case renamed with its capability is renamed too."""

    def __init__(self) -> None:
        self.gone, new = scenarios()
        self.lost, cases = test_cases()
        moved = capability_renames()

        def cap(identity: str) -> str:
            name = identity.split(": ", 1)[0]
            return moved.get(name, name)

        for capability in sorted({cap(s) for s in self.gone}):
            old = sorted(s for s in self.gone if cap(s) == capability and s in self.lost)
            fresh = sorted(s for s in new if cap(s) == capability and s in cases)
            for before, _ in zip(old, fresh):
                self.gone.discard(before)
                self.lost.discard(before)
        for case in list(self.lost):
            name, _, title = case.partition(": ")
            if name in moved and f"{moved[name]}: {title}" in cases:
                self.lost.discard(case)


def delta_requirements(text: str) -> dict[str, list[str]]:
    """Requirement names per delta section (ADDED, MODIFIED, REMOVED, RENAMED) of a delta spec."""
    marks = list(DELTA_SECTION.finditer(text))
    ends = [m.start() for m in marks[1:]] + [len(text)]
    found: dict[str, list[str]] = {}
    for mark, end in zip(marks, ends):
        found.setdefault(mark.group(1), []).extend(REQUIREMENT.findall(text, mark.end(), end))
    return found


def words(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", name.lower()).strip()


def near(a: str, b: str) -> bool:
    return difflib.SequenceMatcher(None, words(a), words(b)).ratio() >= NEAR_NAME


def readded_requirements() -> list[str]:
    """A REMOVED requirement ADDED again (same or near name): a way to change its bounds unasked."""
    reasons = []
    for path in changed_files(r"openspec/changes/[^/]+/specs/.+\.md"):
        reqs = delta_requirements(open(path).read())
        for gone in reqs.get("REMOVED", []):
            again = [a for a in reqs.get("ADDED", []) if near(gone, a)]
            if again:
                reasons.append(f"removes and re-adds requirement '{gone}' as '{again[0]}' ({path}): check its bounds")
    return reasons


def decision(text: str) -> str:
    return "\n\n".join(m.group(0).strip() for m in DECISION.finditer(text))


def rewritten_decisions() -> list[str]:
    """A proposal whose user `## Decision` text differs from its version where the branch forked (the merge base): a
    Decision the auditor extended on the base after the last sync is not the branch's rewrite (run 36516373)."""
    reasons = []
    fork = git("merge-base", "HEAD", BASE).strip()
    for path in changed_files(r"openspec/changes/[^/]+/proposal\.md"):
        show = subprocess.run(["git", "show", f"{fork}:{path}"], capture_output=True, text=True)
        before = decision(show.stdout) if show.returncode == 0 else ""
        if before and decision(open(path).read()) != before:
            reasons.append(f"rewrites the user's ## Decision in {path}")
    return reasons


def case_names(text: str) -> set[str]:
    return {CASE_KEY.findall(m.group(1))[-1] for l in text.splitlines() if (m := CASE_CHAIN.match(l))}


def moved_test_files(base: str, deleted: list[str]) -> bool:
    """Every case of the deleted test files still exists by name in a test file of the branch."""
    kept = {path for path in staged("ls-files", "--cached", "--", "tests/").split() if path.endswith(".lua")}
    present = set().union(*(case_names(open(path).read()) for path in kept if os.path.isfile(path)))
    return all(case_names(git("show", f"{base}:{path}")) <= present for path in deleted)


CASE_SNAPSHOT = "case-snapshot.json"  # verdict.py: the case names at the end of a build pass
CASE_SEEN = "case-seen.json"  # tests/parallel.lua: {file, case} of each `make test` run; verdict.py clears it
DROPPED_CASES = "dropped-cases.json"  # gate.py: names a later pass dropped, for the judge


def tree_case_names() -> set[str]:
    """Test case names in the worktree's tests/ files, committed or not."""
    return set().union(*(case_names(p.read_text(errors="replace")) for p in pathlib.Path("tests").rglob("*.lua")))


def base_case_names() -> set[str]:
    base = git("merge-base", "HEAD", BASE).strip()
    found = subprocess.run(["git", "grep", "-h", "-E", r"^\s*T\[", base, "--", "tests/"], capture_output=True, text=True)
    return case_names(found.stdout)


def dropped_cases(seen: list[str]) -> list[str]:
    """Names of `seen` (cases an earlier build pass had) that neither the worktree nor the base has:
    a test the build added and then removed."""
    gone = set(seen) - tree_case_names()
    return sorted(gone - base_case_names()) if gone else []


def seen_case_names(artifacts: pathlib.Path) -> set[str]:
    """Case names of verdict's last snapshot and of every `make test` run since (CASE_SEEN, tests/parallel.lua)."""
    snapshot, seen = artifacts / CASE_SNAPSHOT, artifacts / CASE_SEEN
    names = set(json.loads(snapshot.read_text())) if snapshot.exists() else set()
    return names | ({entry["case"] for entry in json.loads(seen.read_text())} if seen.exists() else set())


def record_dropped(artifacts: pathlib.Path) -> list[str]:
    """Cases dropped since verdict's last snapshot (a case added and removed within the pass included),
    added to DROPPED_CASES so the judge still sees them."""
    record = artifacts / DROPPED_CASES
    names = dropped_cases(sorted(seen_case_names(artifacts)))
    if names:
        known = json.loads(record.read_text()) if record.exists() else []
        record.write_text(json.dumps(sorted(set(known) | set(names))))
    return names


def still_dropped(artifacts: pathlib.Path) -> list[str]:
    """Recorded dropped cases that the branch has not restored."""
    record = artifacts / DROPPED_CASES
    return dropped_cases(json.loads(record.read_text())) if record.exists() else []


def xfail_refs(text: str) -> list[str]:
    """Change ids named by each `H.xfail(` in a test file: a string literal (possibly on the next line)
    or a local string constant holding it; "" when the reason cannot be resolved."""
    consts = dict(LOCAL_STRING.findall(text))
    refs = []
    for m in XFAIL_ARG.finditer(text):
        reason = m.group(1) or consts.get(m.group(2) or "", "")
        refs.append(re.match(r"[\w.-]*", reason).group(0))
    return refs


def unqueued_xfails(base: str) -> list[str]:
    """Each changed test file's xfails must each name a queued change (openspec/changes/<id>)."""
    changed = staged("diff", "--cached", "--diff-filter=AM", "--name-only", base, "--", "tests/").split()
    out = []
    for path in changed:
        if not path.endswith(".lua") or not os.path.isfile(path):
            continue
        for ref in xfail_refs(staged("show", f":{path}")):
            if not ref or not os.path.isdir(f"openspec/changes/{ref}"):
                out.append(f"xfail without a queued openspec change: {path} ({ref or 'unresolved reason'})")
    return out


def planned_removals(changes: str = "openspec/changes") -> set[str]:
    """`<capability>: <scenario>` of every scenario a change's spec delta lists under `## REMOVED
    Requirements`: the spec removes that behaviour, so its test case goes with it (exact names only)."""
    found: set[str] = set()
    for spec in pathlib.Path(os.environ.get("LOOP_CHANGES_DIR") or changes).glob("*/specs/*/spec.md"):
        text = spec.read_text()
        marks = list(DELTA_SECTION.finditer(text))
        for mark, end in zip(marks, [m.start() for m in marks[1:]] + [len(text)]):
            if mark.group(1) == "REMOVED":
                found |= {f"{spec.parent.name}: {t}" for t in SCENARIO_LINE.findall(text[mark.end() : end])}
    return found


SCENARIO_LINE = re.compile(r"^#### Scenario:\s*(.+?)\s*$", re.MULTILINE)


def hard_rule_violations() -> list[str]:
    base = git("merge-base", "HEAD", BASE).strip()
    tests = diff("tests/")
    reasons = []
    planned = planned_removals()
    removed_cases = Coverage().lost
    lost = sorted(removed_cases - planned)  # by name: an unrelated new case cannot offset a lost one
    deleted = staged("diff", "--cached", "--diff-filter=D", "--name-only", base, "--", "tests/").split()
    only_planned = deleted and all(case_names(git("show", f"{base}:{path}")) <= planned for path in deleted)
    if deleted and (lost or not (moved_test_files(base, deleted) or only_planned)):  # moved or spec-removed: no loss
        reasons.append("test files deleted: " + ", ".join(deleted))
    if lost:
        reasons.append(f"{len(lost)} test case(s) removed: " + ", ".join(lost))
    reasons += unqueued_xfails(base)
    markers = staged("grep", "-n", "-E", "^(<<<<<<<|>>>>>>>) ", "--cached", check=False)
    if markers:
        reasons.append("conflict markers committed: " + markers.splitlines()[0][:120])
    return reasons


PLAN_FILES = re.compile(r"proposal\.md|\.openspec\.yaml|specs/.+\.md")


def plan_files(change: str) -> dict[str, str]:
    """sha256 of the change's planning files (proposal.md, .openspec.yaml, spec deltas) by path."""
    folder = os.path.join("openspec/changes", change)
    found = {}
    for root, _, names in os.walk(folder) if change else []:
        for name in names:
            path = os.path.join(root, name)
            if PLAN_FILES.fullmatch(os.path.relpath(path, folder)):
                found[path] = hashlib.sha256(open(path, "rb").read()).hexdigest()
    return found


def plan_edits(before: dict[str, str], change: str) -> list[str]:
    """Planning files of the change added, edited or removed since the `before` snapshot."""
    after = plan_files(change)
    return sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))


def breaking_changes() -> list[str]:
    plugins = diff("lua/gleb/plugins")
    # compare plugin names, not lines: moving a spec into another's dependencies changes lines only
    plus = {n for l in lines(plugins, "+") for n in PLUGIN_NAME.findall(l)}
    minus = {n for l in lines(plugins, "-") for n in PLUGIN_NAME.findall(l)}
    added, removed = sorted(plus - minus), sorted(minus - plus)
    lock = diff("lazy-lock.json")
    lock_old = {l.split(":")[0].strip() for l in lines(lock, "-")}
    lock_new = {l.split(":")[0].strip() for l in lines(lock, "+") if l.strip().startswith('"')}
    reasons = []
    if added or lock_new - lock_old:
        reasons.append("adds a plugin: " + ", ".join(sorted(lock_new - lock_old) or added))
    if removed or lock_old - lock_new:
        reasons.append("removes a plugin: " + ", ".join(sorted(lock_old - lock_new) or removed))
    keymaps = diff("lua/gleb/keymaps.lua")
    if any(re.search(r"keymap\.set|mapleader|nvim_set_keymap", l) for l in lines(keymaps, "+") + lines(keymaps, "-")):
        reasons.append("changes core keymaps (lua/gleb/keymaps.lua)")
    gone = sorted(Coverage().gone)  # a tested rename is not a removal
    removed_req = any(l.startswith("## REMOVED Requirements") for l in lines(diff("openspec/changes"), "+"))
    if gone or removed_req:
        reasons.append("removes behaviour: " + ("; ".join(sorted(gone)) if gone else "REMOVED Requirements"))
    return reasons + readded_requirements() + rewritten_decisions()


if __name__ == "__main__":  # `make self-check`: the gate's hard rules, one line each; exit 1 when any
    import sys

    found = hard_rule_violations()
    print("\n".join(f"hard rule: {v}" for v in found), end="\n" if found else "")
    sys.exit(1 if found else 0)
