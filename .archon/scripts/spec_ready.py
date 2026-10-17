"""The work-queue `ready` node: a queued change whose folder the user already completed (tasks.md with
tasks, no Blocked/Unblocked section left to settle) and which already passes the spec gate (spec_gate.gate)
skips the AI spec step, which otherwise rewrote the user's concrete scenarios into vaguer ones.
Prints {ok, log} for INPUTS_CHANGE under LOOP_CHANGES_DIR (fixtures) or openspec/changes; exits 0.
"""

import json
import os
import pathlib
import re

from spec_gate import gate

TASK = re.compile(r"^- \[[ x]\] \d", re.MULTILINE)
UNSETTLED = re.compile(r"^## (Blocked|Unblocked)\b", re.MULTILINE)
AUDITOR = re.compile(r"^## Decision \(auditor\b", re.MULTILINE)


def ready(change: str) -> dict:
    folder = pathlib.Path(os.environ.get("LOOP_CHANGES_DIR") or "openspec/changes") / change
    tasks = folder / "tasks.md"
    text = tasks.read_text() if tasks.is_file() else ""
    if not TASK.search(text):
        return {"ok": False, "log": "no tasks.md tasks"}
    if UNSETTLED.search(text):
        return {"ok": False, "log": "tasks.md has a Blocked or Unblocked section to settle"}
    proposal = folder / "proposal.md"
    if proposal.is_file() and AUDITOR.search(proposal.read_text()):  # its task splits and scenarios go into the artifacts
        return {"ok": False, "log": "proposal.md has an auditor Decision for the spec step to apply"}
    return gate(change)


if __name__ == "__main__":
    print(json.dumps(ready(os.environ.get("INPUTS_CHANGE", ""))))
