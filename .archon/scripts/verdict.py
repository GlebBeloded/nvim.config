"""End of one build pass: passed when every gate holds (check, spec, tasks, hard rules, /opsx:verify
without CRITICAL, AI review approves). `feedback` carries only the failures and blocking review findings
(minor ones are the judge's notes on ship, findings.py), so the next pass's fix step reads nothing else; `notes` (flaky cases gate.py passed on rerun) is no finding. The loop stops when passed, after MAX_ATTEMPTS, or as soon as the
change has a `## Blocked` section (blocked.py: no fix pass can resolve it) or the gate reports `infra`
(the sandbox failed twice: no fix pass can resolve that either), so an exhausted or blocked
loop reaches the judge instead of failing the run. A `## Stuck` section (a behaviour still red after
both attempts) is a failed gate `stuck`, never an end: its text leads the feedback and `stuck` lets the
fix pass run at higher effort; the fix pass deletes it once green. Lessons are persisted by the judge
(escalation.py) after the loop, never here: docs/workflow.md stays clean between passes.
"""

import json
import os
import pathlib
import subprocess

from blocked import blocked_text, stuck_text
from findings import blocking_findings
from integrity import CASE_SEEN, CASE_SNAPSHOT, hard_rule_violations, plan_files, tree_case_names
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
failures = str(value("failures", "") or "")
stuck = stuck_text(os.environ.get("INPUTS_CHANGE", ""))
gates = {
    "tests": value("green", False) is True,
    "spec": value("spec_ok", False) is True,
    "tasks": value("tasks_done", False) is True,
    "rules": not violations and not any(line.startswith("hard rule: ") for line in failures.splitlines()),  # gate.py's too
    "verify": int(value("critical", -1)) == 0,
    "review": value("approve", False) is True,
    "stuck": not stuck,
}
if value("green", False) is not True or value("spec_ok", False) is not True or int(value("critical", -1)) != 0:
    gates.pop("review")  # review did not run this pass: not a failed gate (tests, spec or verify already is)
passed = all(gates.values())
attempt = int(value("attempt", 0))
blocked = "" if passed else blocked_text(os.environ.get("INPUTS_CHANGE", ""))
infra = "" if passed else str(value("infra", "") or "")
exhausted = not passed and not blocked and not infra and attempt >= MAX_ATTEMPTS
feedback = [f"stuck (tasks.md, earlier attempts; fix it, then delete the section): {stuck}" if stuck else "", failures]
feedback += [f"hard rule: {v}" for v in violations if f"hard rule: {v}" not in failures]  # gate.py may list them
artifacts = pathlib.Path(os.environ.get("ARTIFACTS_DIR", "."))
scope = artifacts / "fix-scope.md"
if "review" not in gates and scope.exists():  # the review did not see it: send it to the next pass
    feedback.append(scope.read_text().strip())
drop_overturned(artifacts, "review" in gates and not gates["review"])  # lessons of a rejected pass are unverified
# the next fix pass starts here: gate.py compares the change's planning files against this snapshot
(artifacts / "plan-snapshot.json").write_text(json.dumps(plan_files(os.environ.get("INPUTS_CHANGE", ""))))
(artifacts / CASE_SNAPSHOT).write_text(json.dumps(sorted(tree_case_names())))  # gate.py: a case the next pass drops
(artifacts / CASE_SEEN).unlink(missing_ok=True)  # the snapshot holds them now; the next pass's runs start afresh
feedback += [f"verify: {value('verify_findings', '')}" if int(value("critical", -1)) > 0 and value("verify_findings", "") else ""]
# only blocking findings go to the fix pass; minor ones stay in review_findings (the judge lists them on ship)
feedback += [f"review: {blocking_findings(value('review_findings', ''))}" if value("approve", False) is not True and value("review_findings", "") else ""]
flaky = value("flaky", []) or []
notes = "flaky test cases (failed, then passed on rerun): " + ", ".join(map(str, flaky)) if isinstance(flaky, list) and flaky else ""
print(
    json.dumps(
        {
            "done": passed or exhausted or bool(blocked) or bool(infra),
            "passed": passed,
            "exhausted": exhausted,
            "blocked": bool(blocked),
            "stuck": bool(stuck),
            "infra": infra,
            "attempt": attempt,
            "failed_gates": ",".join(k for k, ok in gates.items() if not ok),
            "feedback": "\n\n".join(f for f in feedback if f.strip())[:FEEDBACK_CHARS],
            "weakened_scenario": value("weakened_scenario", False) is True,
            "weakened_test": value("weakened_test", False) is True,
            "notes": notes,
            # the last review's findings: quoted by the judge when it does not ship, minor ones listed as notes
            "review_findings": str(value("review_findings", "") or ""),
        }
    )
)
