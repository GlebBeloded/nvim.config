"""Join after an optional approval gate. go is true when the gate was not needed (INPUTS_NEEDED empty
or "false", gate skipped) or the user picked `approve`; feedback carries the user's text onward.
"""

import json
import os

decision = os.environ.get("INPUTS_DECISION", "") or "auto"
needed = os.environ.get("INPUTS_NEEDED", "").strip().lower() not in ("", "false")
go = decision == "approve" or (not needed and decision == "auto")
print(json.dumps({"go": go, "decision": decision, "feedback": os.environ.get("INPUTS_FEEDBACK", "")}))
