"""Judge after the build loop, no AI: `reject` when the loop is exhausted or a hard rule is broken
(never shipped; followup.py queues the work), `ask` only for breaking changes (the user decides),
otherwise `ship`. Writes a short escalation.md and prints {decision, escalate, reasons}.
"""

import json
import os
from pathlib import Path

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
ask = [] if reject else breaking_changes()
decision = "reject" if reject else "ask" if ask else "ship"

summary = "\n".join("- " + r for r in reject + ask) or "- none"
with open(os.path.join(os.environ.get("ARTIFACTS_DIR", "."), "escalation.md"), "w") as f:
    f.write(f"# Judge: {decision}\n\n{summary}\n")
print(json.dumps({"decision": decision, "escalate": decision == "ask", "reasons": summary}))
