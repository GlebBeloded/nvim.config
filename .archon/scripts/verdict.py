"""End of one build pass: passed when every gate holds (check, spec, tasks, hard rules, /opsx:verify
without CRITICAL, AI review approves). `feedback` carries only the failures and findings, so the next
pass's fix step reads nothing else; `notes` (flaky cases gate.py passed on rerun) is no finding. The loop stops when passed, after MAX_ATTEMPTS, or as soon as the
change has a `## Blocked` section (blocked.py: no fix pass can resolve it), so an exhausted or blocked
loop reaches the judge instead of failing the run. Lessons are persisted by the judge
(escalation.py) after the loop, never here: docs/workflow.md stays clean between passes.
"""

import json
import os
import pathlib
import subprocess

from blocked import blocked_text
from integrity import hard_rule_violations, plan_files
from lessons import drop_overturned

MAX_ATTEMPTS = 3
FEEDBACK_CHARS = 6000


def value(name: str, default):
    raw = os.environ.get("INPUTS_" + name.upper(), "")
    try:
        return json.loads(raw) if raw != "" else default
    except json.JSONDecodeError:
        return raw


def hard_rules() -> list[str]:
    try:
        return hard_rule_violations()
    except subprocess.CalledProcessError:  # not a git repo, or no base branch: nothing to compare
        return []


violations = hard_rules()
gates = {
    "tests": value("green", False) is True,
    "spec": value("spec_ok", False) is True,
    "tasks": value("tasks_done", False) is True,
    "rules": not violations,
    "verify": int(value("critical", -1)) == 0,
    "review": value("approve", False) is True,
}
if value("green", False) is not True or value("spec_ok", False) is not True or int(value("critical", -1)) != 0:
    gates.pop("review")  # review did not run this pass: not a failed gate
    gates["review_skipped"] = False
passed = all(gates.values())
attempt = int(value("attempt", 0))
blocked = "" if passed else blocked_text(os.environ.get("INPUTS_CHANGE", ""))
exhausted = not passed and not blocked and attempt >= MAX_ATTEMPTS
failures = str(value("failures", "") or "")
feedback = [failures]
feedback += [f"hard rule: {v}" for v in violations if f"hard rule: {v}" not in failures]  # gate.py may list them
artifacts = pathlib.Path(os.environ.get("ARTIFACTS_DIR", "."))
scope = artifacts / "fix-scope.md"
if "review" not in gates and scope.exists():  # the review did not see it: send it to the next pass
    feedback.append(scope.read_text().strip())
drop_overturned(artifacts, "review" in gates and not gates["review"])  # lessons of a rejected pass are unverified
# the next fix pass starts here: gate.py compares the change's planning files against this snapshot
(artifacts / "plan-snapshot.json").write_text(json.dumps(plan_files(os.environ.get("INPUTS_CHANGE", ""))))
feedback += [f"verify: {value('verify_findings', '')}" if int(value("critical", -1)) > 0 and value("verify_findings", "") else ""]
feedback += [f"review: {value('review_findings', '')}" if value("approve", False) is not True and value("review_findings", "") else ""]
flaky = value("flaky", []) or []
notes = "flaky test cases (failed, then passed on rerun): " + ", ".join(map(str, flaky)) if isinstance(flaky, list) and flaky else ""
print(
    json.dumps(
        {
            "done": passed or exhausted or bool(blocked),
            "passed": passed,
            "exhausted": exhausted,
            "blocked": bool(blocked),
            "attempt": attempt,
            "failed_gates": ",".join(k for k, ok in gates.items() if not ok),
            "feedback": "\n\n".join(f for f in feedback if f.strip())[:FEEDBACK_CHARS],
            "weakened_scenario": value("weakened_scenario", False) is True,
            "weakened_test": value("weakened_test", False) is True,
            "notes": notes,
        }
    )
)
