"""Deterministic checks on the branch diff against its merge-base with `auto`, split by who decides:
`hard_rule_violations` (never shipped: the build loop fixes them, the judge rejects them) and
`breaking_changes` (the only reasons the user is asked, docs/workflow.md, Gates).
"""

import difflib
import os
import re
import subprocess

BASE = os.environ.get("BASE_BRANCH") or "auto"
PLUGIN_NAME = re.compile(r'"([\w.-]+/[\w.-]+)"')
CASE_RE = re.compile(r'^\s*T\["')
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


def hard_rule_violations() -> list[str]:
    base = git("merge-base", "HEAD", BASE).strip()
    tests = diff("tests/")
    reasons = []
    deleted = git("diff", "--cached", "--diff-filter=D", "--name-only", base, "--", "tests/").split()
    if deleted:
        reasons.append("test files deleted: " + ", ".join(deleted))
    lost = len([l for l in lines(tests, "-") if CASE_RE.match(l)]) - len([l for l in lines(tests, "+") if CASE_RE.match(l)])
    if lost > 0:
        reasons.append(f"{lost} test case(s) removed")
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
    specs = diff("openspec/specs")
    gone = set(l for l in lines(specs, "-") if l.startswith("#### Scenario:")) - set(
        l for l in lines(specs, "+") if l.startswith("#### Scenario:")
    )
    removed_req = any(l.startswith("## REMOVED Requirements") for l in lines(diff("openspec/changes"), "+"))
    if gone or removed_req:
        reasons.append("removes behaviour: " + ("; ".join(sorted(gone)) if gone else "REMOVED Requirements"))
    return reasons + readded_requirements() + rewritten_decisions()
