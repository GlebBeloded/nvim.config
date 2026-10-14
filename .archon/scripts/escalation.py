"""Judge after the build loop, no AI: `ask` when the change has a `## Blocked` section (quoted in
escalation.md; ship-decide never ships it, verdict.py's `blocked`), `reject` when the loop is exhausted
or a hard rule is broken (never shipped; followup.py queues the work), `ask` for breaking changes (the
user decides), otherwise `ship`. `notes` (flaky cases, `loop:` notes) are listed, never decide; the
last review's findings follow a non-ship decision, so a re-queued change says what to fix. Writes a
short escalation.md and prints {decision, escalate, reasons}.
"""

import json
import os
from pathlib import Path

from blocked import blocked_text, loop_notes
from integrity import breaking_changes, hard_rule_violations
from lessons import persist_lessons

FINDINGS_CHARS = 1500  # indented: no finding line reads as a markdown heading of the proposal


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
ask = ["blocked: " + blocked] if blocked else [] if reject else breaking_changes()
decision = "ask" if blocked else "reject" if reject else "ask" if ask else "ship"

summary = "\n".join("- " + r for r in reject + ask) or "- none"
findings = os.environ.get("INPUTS_REVIEW_FINDINGS", "").strip()[:FINDINGS_CHARS]
if findings and decision != "ship":  # followup.py writes the reasons under `## Rejected run`: say what to fix
    summary += "\n- review findings:\n" + "\n".join("  " + line for line in findings.splitlines())
notes = os.environ.get("INPUTS_NOTES", "").strip()
summary += f"\n- note: {notes}" if notes else ""  # flaky cases a gate rerun passed: never a reason
summary += "".join(f"\n- note: {n}" for n in loop_notes(os.environ.get("INPUTS_CHANGE", ""), artifacts))
with open(artifacts / "escalation.md", "w") as f:
    f.write(f"# Judge: {decision}\n\n{summary}\n")
print(json.dumps({"decision": decision, "escalate": decision == "ask", "reasons": summary}))
