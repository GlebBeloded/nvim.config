"""End of one build pass: passed when every gate holds (check, spec, tasks, hard rules, /opsx:verify
without CRITICAL, AI review approves). `feedback` carries only the failures and findings, so the next
pass's fix step reads nothing else. The loop stops when passed or after MAX_ATTEMPTS, so an exhausted
loop reaches the judge instead of failing the run.
"""

import json
import os
import subprocess
from pathlib import Path

from integrity import hard_rule_violations
from lessons import persist_lessons

MAX_ATTEMPTS = 3
FEEDBACK_CHARS = 6000

persist_lessons(Path(os.environ.get("ARTIFACTS_DIR", ".")))


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
exhausted = not passed and attempt >= MAX_ATTEMPTS
feedback = [str(value("failures", "") or "")]
feedback += [f"hard rule: {v}" for v in violations]
feedback += [f"verify: {value('verify_findings', '')}" if int(value("critical", -1)) > 0 else ""]
feedback += [f"review: {value('review_findings', '')}" if value("approve", False) is not True and value("review_findings", "") else ""]
print(
    json.dumps(
        {
            "done": passed or exhausted,
            "passed": passed,
            "exhausted": exhausted,
            "attempt": attempt,
            "failed_gates": ",".join(k for k, ok in gates.items() if not ok),
            "feedback": "\n\n".join(f for f in feedback if f.strip())[:FEEDBACK_CHARS],
            "weakened_scenario": value("weakened_scenario", False) is True,
            "weakened_test": value("weakened_test", False) is True,
        }
    )
)
