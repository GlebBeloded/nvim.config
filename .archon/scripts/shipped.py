"""Result of nvim-deliver: the ship output, or the reconcile loop's (its last `reship`) when ship
reported a conflict. INPUTS_SHIP and INPUTS_RECONCILE hold the nodes' JSON output; RECONCILE is empty
when the loop was skipped.
"""

import json
import os


def shipped(ship: str, reconcile: str) -> dict:
    result = json.loads(ship)
    if result.get("conflict") and reconcile.strip():
        result = json.loads(reconcile)
    return result


print(json.dumps(shipped(os.environ.get("INPUTS_SHIP", "{}"), os.environ.get("INPUTS_RECONCILE", ""))))
