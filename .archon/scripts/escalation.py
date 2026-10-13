"""Judge after the build loop, no AI: `ask` when the change has a `## Blocked` section (quoted in
escalation.md; ship-decide never ships it, verdict.py's `blocked`), `reject` when the loop is exhausted
or a hard rule is broken (never shipped; followup.py queues the work), `ask` for breaking changes (the
user decides), otherwise `ship`. `notes` (flaky cases) are listed, never decide. Writes a short escalation.md and prints {decision, escalate, reasons}.
"""

import json
import os
from pathlib import Path

from blocked import blocked_text
from integrity import breaking_changes, hard_rule_violations
from lessons import persist_lessons


def flag(name: str) -> bool:
    return os.environ.get("INPUTS_" + name.upper(), "").strip().lower() == "true"


persist_lessons(Path(os.environ.get("ARTIFACTS_DIR", ".")))
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
notes = os.environ.get("INPUTS_NOTES", "").strip()
summary += f"\n- note: {notes}" if notes else ""  # flaky cases a gate rerun passed: never a reason
with open(os.path.join(os.environ.get("ARTIFACTS_DIR", "."), "escalation.md"), "w") as f:
    f.write(f"# Judge: {decision}\n\n{summary}\n")
print(json.dumps({"decision": decision, "escalate": decision == "ask", "reasons": summary}))
