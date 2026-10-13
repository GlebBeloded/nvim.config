"""Escalation check before ship. The user is pinged (approval gate) only when one of these holds:
new plugin dependency, core keymap change, spec scenario removed or weakened, test deleted or
weakened, or the build loop exhausted its attempts. Everything else ships automatically.
Deterministic checks read the diff against the merge-base with the base branch (`auto`); the review node adds the
judgment flags (weakened scenario/test).
"""

import json
import os
import re
import subprocess
from pathlib import Path

from lessons import persist_lessons

BASE = os.environ.get("BASE_BRANCH") or "auto"  # make targets pass --base auto


def git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout


def flag(name: str) -> bool:
    raw = os.environ.get("INPUTS_" + name.upper(), "")
    return raw.strip().lower() == "true"


def lines(diff: str, sign: str) -> list[str]:
    return [l[1:] for l in diff.splitlines() if l.startswith(sign) and not l.startswith(sign * 3)]


persist_lessons(Path(os.environ.get("ARTIFACTS_DIR", ".")))
git("add", "-A")  # ship commits everything; stage now so new files show in the diff
base = git("merge-base", "HEAD", BASE).strip()
diff = lambda *paths: git("diff", "--cached", base, "--", *paths)  # noqa: E731
reasons = []

plugin_re = re.compile(r'^\s*\{?\s*"[\w.-]+/[\w.-]+"')
added_plugins = [l.strip() for l in lines(diff("lua/gleb/plugins"), "+") if plugin_re.match(l)]
removed_plugins = [l.strip() for l in lines(diff("lua/gleb/plugins"), "-") if plugin_re.match(l)]
new_plugins = [p for p in added_plugins if p not in removed_plugins]
lock_added = [l for l in lines(diff("lazy-lock.json"), "+") if l.strip().startswith('"')]
lock_removed = {l.split(":")[0] for l in lines(diff("lazy-lock.json"), "-")}
new_lock = [l.split(":")[0].strip() for l in lock_added if l.split(":")[0] not in lock_removed]
if new_plugins or new_lock:
    reasons.append("new plugin dependency: " + ", ".join(new_plugins + new_lock))

keymap_diff = diff("lua/gleb/keymaps.lua")
if any(re.search(r"keymap\.set|mapleader|nvim_set_keymap", l) for l in lines(keymap_diff, "+") + lines(keymap_diff, "-")):
    reasons.append("core keymap change (lua/gleb/keymaps.lua)")

removed_scenarios = [l for l in lines(diff("openspec/specs"), "-") if l.startswith("#### Scenario:")]
added_scenarios = set(l for l in lines(diff("openspec/specs"), "+") if l.startswith("#### Scenario:"))
gone = [s for s in removed_scenarios if s not in added_scenarios]
removed_req = "## REMOVED Requirements" in diff("openspec/changes")
if gone or removed_req:
    reasons.append("spec scenario removed: " + ("; ".join(gone) if gone else "REMOVED Requirements in change"))
if flag("weakened_scenario"):
    reasons.append("review: spec scenario weakened")

deleted_tests = git("diff", "--cached", "--diff-filter=D", "--name-only", base, "--", "tests/").split()
case_re = re.compile(r'^\s*T\["')
tests_diff = diff("tests/")
cases_lost = len([l for l in lines(tests_diff, "-") if case_re.match(l)]) - len(
    [l for l in lines(tests_diff, "+") if case_re.match(l)]
)
new_xfail = [l for l in lines(tests_diff, "+") if "H.xfail(" in l]
if deleted_tests or cases_lost > 0 or new_xfail:
    reasons.append(
        f"test deleted or disabled: files={deleted_tests} cases_lost={max(cases_lost, 0)} new_xfail={len(new_xfail)}"
    )
if flag("weakened_test"):
    reasons.append("review: test weakened")

if flag("exhausted"):
    reasons.append("fix loop exhausted (3 attempts) with gates still red: " + os.environ.get("INPUTS_FAILED_GATES", ""))

summary = "\n".join("- " + r for r in reasons) or "- none"
artifacts = os.environ.get("ARTIFACTS_DIR", ".")
with open(os.path.join(artifacts, "escalation.md"), "w") as f:
    f.write("# Escalation check\n\n" + summary + "\n")
print(json.dumps({"escalate": bool(reasons), "reasons": summary}))
