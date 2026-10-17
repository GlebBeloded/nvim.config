"""Result of nvim-deliver: the ship output, or the reconcile loop's (its last `reship`) when ship
reported a conflict. INPUTS_SHIP and INPUTS_RECONCILE hold the nodes' JSON output; RECONCILE is empty
when the loop was skipped.
"""

import json
import os
import sys


def shipped(ship: str, reconcile: str) -> dict:
    result = json.loads(ship)
    if result.get("conflict") and reconcile.strip():
        result = json.loads(reconcile)
    return result


result = shipped(os.environ.get("INPUTS_SHIP", "{}"), os.environ.get("INPUTS_RECONCILE", ""))
print(json.dumps(result))
if not result.get("merged"):  # the reconcile loop ran out with a red regate or a conflict: the run did not ship
    print(f"not shipped: {result.get('log') or 'conflict with auto'}", file=sys.stderr)
    sys.exit(1)
