"""Judge after the build loop, no AI: `ask` when the change has a `## Blocked` section (quoted in
escalation.md; ship-decide never ships it, verdict.py's `blocked`), `reject` when the loop is exhausted
or a hard rule is broken (never shipped; followup.py queues the work), `infra` when the build loop stopped
on the sandbox failing twice (gate.py's `infra`: the change did not fail, so it is neither rejected nor
re-queued; the run stops until the host is fixed), `ask` for breaking changes (the user decides), otherwise
`ship`. A `## Stuck` section (a behaviour still red after both attempts, no decision needed) never asks:
an exhausted loop with it is rejected as any other, its text quoted for the re-queued run. `notes` (flaky cases, `loop:` notes) are listed, never decide; the
last review's findings follow a non-ship decision, so a re-queued change says what to fix; on ship its
minor (non-blocking) findings are listed as notes for the auditor. An exhausted loop's reasons quote the first
lines of the last pass's failures (`feedback`), so the re-queued `## Rejected run` is actionable. A test case the build added and then
removed (gate.py's record) and still missing is asked about. Writes a
short escalation.md and prints {decision, escalate, reasons}.
"""

import json
import os
from pathlib import Path

from blocked import blocked_text, loop_notes, stuck_text
from findings import minor_findings
from integrity import breaking_changes, hard_rule_violations, still_dropped
from lessons import persist_lessons

FINDINGS_CHARS = 1500  # indented: no finding line reads as a markdown heading of the proposal
FAILURE_LINES = 12  # of the last pass's failures, quoted under an exhausted loop's reason


def flag(name: str) -> bool:
    return os.environ.get("INPUTS_" + name.upper(), "").strip().lower() == "true"


artifacts = Path(os.environ.get("ARTIFACTS_DIR", "."))
persist_lessons(artifacts)
reject = hard_rule_violations()
if flag("weakened_scenario"):
    reject.append("review: spec scenario weakened")
if flag("weakened_test"):
    reject.append("review: test weakened")
if flag("exhausted"):
    reject.append("fix loop exhausted (3 attempts) with gates still red: " + os.environ.get("INPUTS_FAILED_GATES", ""))
blocked = blocked_text(os.environ.get("INPUTS_CHANGE", ""))
dropped = still_dropped(artifacts)
dropped_reason = ["test added then removed during build: " + ", ".join(dropped)] if dropped else []
ask = ["blocked: " + blocked] if blocked else [] if reject else breaking_changes() + dropped_reason
infra = os.environ.get("INPUTS_INFRA", "").strip()
decision = "ask" if blocked else "reject" if reject else "infra" if infra else "ask" if ask else "ship"
ask = [f"infra: e2e did not run (the sandbox failed twice, not the change): {infra}"] if decision == "infra" else ask

summary = "\n".join("- " + r for r in reject + ask) or "- none"
stuck = stuck_text(os.environ.get("INPUTS_CHANGE", ""))
if stuck and decision != "ship":  # the re-queued run's fix pass starts from these attempts
    summary += "\n- stuck:\n" + "\n".join("  " + line for line in stuck.splitlines())
# the last pass's failures (gate, hard rules) as the fix pass got them; stuck and review text are quoted apart
failures = [p for p in os.environ.get("INPUTS_FEEDBACK", "").split("\n\n") if not p.startswith(("stuck (", "review: "))]
failed = [line for line in "\n".join(failures).splitlines() if line.strip()][:FAILURE_LINES]
if failed and flag("exhausted"):  # the re-queued run's `## Rejected run` says what was still red
    summary += "\n- last failures:\n" + "\n".join("  " + line for line in failed)
findings = os.environ.get("INPUTS_REVIEW_FINDINGS", "").strip()[:FINDINGS_CHARS]
if findings and decision != "ship":  # followup.py writes the reasons under `## Rejected run`: say what to fix
    summary += "\n- review findings:\n" + "\n".join("  " + line for line in findings.splitlines())
if decision == "ship":  # the auditor sees what the review let through
    summary += "".join(f"\n- note: review (minor): {m}" for m in minor_findings(os.environ.get("INPUTS_REVIEW_FINDINGS", "")))
notes = os.environ.get("INPUTS_NOTES", "").strip()
summary += f"\n- note: {notes}" if notes else ""  # flaky cases a gate rerun passed: never a reason
summary += "".join(f"\n- note: {n}" for n in loop_notes(os.environ.get("INPUTS_CHANGE", ""), artifacts))
with open(artifacts / "escalation.md", "w") as f:
    f.write(f"# Judge: {decision}\n\n{summary}\n")
print(json.dumps({"decision": decision, "escalate": decision == "ask", "reasons": summary}))
