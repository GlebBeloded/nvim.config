"""The reconcile loop's reship node. It always runs, because the loop's until_bash reads its `merged`:
a red regate is reported as not merged (so the loop resolves and regates once more instead of failing
on a skipped node, run 1a63f5e1); a green one runs ship.py with the same inputs.
"""

import json
import os
import subprocess
import sys

red = "false" in (os.environ.get("INPUTS_REGATE_GREEN", ""), os.environ.get("INPUTS_REGATE_SPEC_OK", ""))
if red:
    branch = subprocess.run(["git", "rev-parse", "--abbrev-ref", "HEAD"], capture_output=True, text=True).stdout.strip()
    print(json.dumps({"merged": False, "conflict": True, "gate_failed": True, "branch": branch, "commit": "", "files": [], "log": "regate red"}))
    sys.exit(0)
ship = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ship.py")
sys.exit(subprocess.run([sys.executable, ship]).returncode)
