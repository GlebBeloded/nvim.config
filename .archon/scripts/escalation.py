"""Judge after the build loop, no AI, never asks the user (no manual gates): `reject` when the change has a `## Blocked` section (quoted in
escalation.md; ship-decide never ships it, verdict.py's `blocked`), `reject` when the loop is exhausted
or a hard rule is broken (never shipped; followup.py queues the work), `infra` when the build loop stopped
on the sandbox failing twice (gate.py's `infra`: the change did not fail, so it is neither rejected nor
re-queued; the run stops until the host is fixed), `reject` for a broken contract (a re-added requirement, a reworded user `## Decision`), `ship` with a note for other breaking changes, otherwise
`ship`. A `## Stuck` section (a behaviour still red after both attempts, no decision needed) never asks:
an exhausted loop with it is rejected as any other, pointing at it (the branch's tasks.md keeps its text). `notes` (flaky cases, `loop:` notes) are listed, never decide; the
last review's findings follow a non-ship decision, so a re-queued change says what to fix; on ship its
minor (non-blocking) findings are listed as notes for the auditor. An exhausted loop's reasons quote the first
lines of the last pass's failures (verdict.py `failures`), so the re-queued `## Rejected run` is actionable. A test case the build added and then
removed (gate.py's record) and still missing rejects. Writes a
short escalation.md and prints {decision, escalate, reasons}.
"""

import json
import os
from pathlib import Path

from blocked import blocked_text, loop_notes, stuck_text
from findings import minor_findings
from integrity import breaking_changes, hard_rule_violations, readded_requirements, rewritten_decisions, still_dropped
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
    reject.append("fix loop exhausted with gates still red: " + os.environ.get("INPUTS_FAILED_GATES", ""))
blocked = blocked_text(os.environ.get("INPUTS_CHANGE", ""))
dropped = still_dropped(artifacts)
dropped_reason = ["test added then removed during build: " + ", ".join(dropped)] if dropped else []
# no manual gates: a Blocked section (left after the settle and unblock passes), a dropped test or a broken
# contract (a re-added requirement, a reworded user Decision) rejects and is re-queued; any other breaking
# change ships with a note (the user accepts temporary breakage)
contract = readded_requirements() + rewritten_decisions()
reject += (["blocked: " + blocked] if blocked else []) + dropped_reason + contract
breaking = [] if reject else [b for b in breaking_changes() if b not in contract]
ask = []
infra = os.environ.get("INPUTS_INFRA", "").strip()
decision = "reject" if reject else "infra" if infra else "ship"
ask = [f"infra: e2e did not run (the sandbox failed twice, not the change): {infra}"] if decision == "infra" else ask

summary = "\n".join("- " + r for r in reject + ask) or "- none"
summary += "".join(f"\n- note: breaking: {b}" for b in breaking) if decision == "ship" else ""
if stuck_text(os.environ.get("INPUTS_CHANGE", "")) and decision != "ship":  # the branch's tasks.md holds its text
    summary += "\n- stuck: tasks.md `## Stuck` (earlier attempts, kept on the branch: not quoted here)"
# the last pass's gate failures and hard rules (verdict.py `failures`), so `## Rejected run` says what was red
failed = [line for line in os.environ.get("INPUTS_FAILURES", "").splitlines() if line.strip()][:FAILURE_LINES]
if failed and flag("exhausted"):
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
print(json.dumps({"decision": decision, "escalate": False, "reasons": summary}))
