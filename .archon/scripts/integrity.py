"""Deterministic checks on the branch diff against its merge-base with `auto`, split by who decides:
`hard_rule_violations` (never shipped: the build loop fixes them, the judge rejects them) and
`breaking_changes` (the only reasons the user is asked, docs/workflow.md, Gates).
"""

import difflib
import hashlib
import os
import re
import subprocess

BASE = os.environ.get("BASE_BRANCH") or "auto"
PLUGIN_NAME = re.compile(r'"([\w.-]+/[\w.-]+)"')
CASE_CHAIN = re.compile(r'^\s*T((?:\["[^"]+"\])+)')
CASE_KEY = re.compile(r'\["([^"]+)"\]')
SPEC_HEADER = re.compile(r"^diff --git a/openspec/specs/([^/]+)/spec\.md b/openspec/specs/([^/]+)/spec\.md$")
SCENARIO = re.compile(r"^#### Scenario:\s*(.+?)\s*$")
XFAIL_RE = re.compile(r'H\.xfail\(\s*"([\w.-]+)')
DELTA_SECTION = re.compile(r"^## (ADDED|MODIFIED|REMOVED|RENAMED) Requirements\s*$", re.MULTILINE)
REQUIREMENT = re.compile(r"^### Requirement:\s*(.+?)\s*$", re.MULTILINE)
DECISION = re.compile(r"^## Decision\b.*?(?=^## |\Z)", re.MULTILINE | re.DOTALL)
NEAR_NAME = 0.8  # difflib ratio at which a re-ADDED requirement counts as the REMOVED one


def git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout


def lines(diff: str, sign: str) -> list[str]:
    return [l[1:] for l in diff.splitlines() if l.startswith(sign) and not l.startswith(sign * 3)]


def diff(*paths: str) -> str:
    git("add", "-A")  # ship commits everything; stage so new files count
    base = git("merge-base", "HEAD", BASE).strip()
    return git("diff", "--cached", base, "--", *paths)


def changed_files(pattern: str) -> list[str]:
    """Active-change files matching `pattern` that the branch changed and that still exist."""
    base = git("merge-base", "HEAD", BASE).strip()
    names = git("diff", "--cached", "--name-only", base, "--", "openspec/changes").split()
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
    rows = git("diff", "--cached", "-M", "--name-status", base, "--", "openspec/specs").splitlines()
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
    """A proposal whose user `## Decision` text differs from the base branch's version."""
    reasons = []
    for path in changed_files(r"openspec/changes/[^/]+/proposal\.md"):
        show = subprocess.run(["git", "show", f"{BASE}:{path}"], capture_output=True, text=True)
        before = decision(show.stdout) if show.returncode == 0 else ""
        if before and decision(open(path).read()) != before:
            reasons.append(f"rewrites the user's ## Decision in {path}")
    return reasons


def case_names(text: str) -> set[str]:
    return {CASE_KEY.findall(m.group(1))[-1] for l in text.splitlines() if (m := CASE_CHAIN.match(l))}


def moved_test_files(base: str, deleted: list[str]) -> bool:
    """Every case of the deleted test files still exists by name in a test file of the branch."""
    kept = {path for path in git("ls-files", "--cached", "--", "tests/").split() if path.endswith(".lua")}
    present = set().union(*(case_names(open(path).read()) for path in kept if os.path.isfile(path)))
    return all(case_names(git("show", f"{base}:{path}")) <= present for path in deleted)


def hard_rule_violations() -> list[str]:
    base = git("merge-base", "HEAD", BASE).strip()
    tests = diff("tests/")
    reasons = []
    lost = sorted(Coverage().lost)  # by name: an unrelated new case cannot offset a lost one
    deleted = git("diff", "--cached", "--diff-filter=D", "--name-only", base, "--", "tests/").split()
    if deleted and (lost or not moved_test_files(base, deleted)):  # a file whose cases all moved is no loss
        reasons.append("test files deleted: " + ", ".join(deleted))
    if lost:
        reasons.append(f"{len(lost)} test case(s) removed: " + ", ".join(lost))
    for line in lines(tests, "+"):
        if "H.xfail(" not in line:
            continue
        ref = XFAIL_RE.search(line)
        if not ref or not os.path.isdir(f"openspec/changes/{ref.group(1)}"):
            reasons.append("xfail without a queued openspec change: " + line.strip()[:120])
    markers = subprocess.run(["git", "grep", "-n", "-E", "^(<<<<<<<|>>>>>>>) ", "--cached"], capture_output=True, text=True)
    if markers.stdout:
        reasons.append("conflict markers committed: " + markers.stdout.splitlines()[0][:120])
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
