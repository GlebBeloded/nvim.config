"""Deterministic checks on the branch diff against its merge-base with `auto`, split by who decides:
`hard_rule_violations` (never shipped: the build loop fixes them, the judge rejects them) and
`breaking_changes` (the only reasons the user is asked, docs/workflow.md, Gates).
"""

import os
import re
import subprocess

BASE = os.environ.get("BASE_BRANCH") or "auto"
PLUGIN_RE = re.compile(r'^\s*\{?\s*"[\w.-]+/[\w.-]+"')
CASE_RE = re.compile(r'^\s*T\["')
XFAIL_RE = re.compile(r'H\.xfail\(\s*"([\w.-]+)')


def git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout


def lines(diff: str, sign: str) -> list[str]:
    return [l[1:] for l in diff.splitlines() if l.startswith(sign) and not l.startswith(sign * 3)]


def diff(*paths: str) -> str:
    git("add", "-A")  # ship commits everything; stage so new files count
    base = git("merge-base", "HEAD", BASE).strip()
    return git("diff", "--cached", base, "--", *paths)


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
    added = [l.strip() for l in lines(plugins, "+") if PLUGIN_RE.match(l)]
    removed = [l.strip() for l in lines(plugins, "-") if PLUGIN_RE.match(l)]
    lock = diff("lazy-lock.json")
    lock_old = {l.split(":")[0].strip() for l in lines(lock, "-")}
    lock_new = {l.split(":")[0].strip() for l in lines(lock, "+") if l.strip().startswith('"')}
    reasons = []
    if [p for p in added if p not in removed] or lock_new - lock_old:
        reasons.append("adds a plugin: " + ", ".join(sorted(lock_new - lock_old) or added))
    if [p for p in removed if p not in added] or lock_old - lock_new:
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
    return reasons
