"""Join after the judge or a spec step (no manual gates remain: callers pass decision `auto` and needed
"false"). go is true when no gate is needed (INPUTS_NEEDED empty or "false") with decision `auto`, or on
`approve`, and never when the judge's INPUTS_VERDICT is `reject` or `infra` (the run stops) or INPUTS_BLOCKED
is true (a blocked change is re-queued, never shipped); feedback carries any user text onward.
"""

import json
import os

decision = os.environ.get("INPUTS_DECISION", "") or "auto"
needed = os.environ.get("INPUTS_NEEDED", "").strip().lower() not in ("", "false")
blocked = os.environ.get("INPUTS_BLOCKED", "").strip().lower() == "true"
verdict = os.environ.get("INPUTS_VERDICT", "").strip().lower()
rejected = blocked or verdict == "reject"
go = verdict != "infra" and not rejected and (decision == "approve" or (not needed and decision == "auto"))
# cancel: stop the run (not just this block) when not going; INPUTS_CANCEL_ON_REJECT="false" keeps it running
cancel = not go and os.environ.get("INPUTS_CANCEL_ON_REJECT", "true").strip().lower() != "false"
print(
    json.dumps(
        {"go": go, "cancel": cancel, "decision": "reject" if rejected else "infra" if verdict == "infra" else decision, "feedback": os.environ.get("INPUTS_FEEDBACK", "")}
    )
)
