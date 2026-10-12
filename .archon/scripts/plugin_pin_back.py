"""plugin-update after nvim-deliver: when it did not merge (escalation rejected), keep the old pin.
Save the attempt as <branch>-attempt, reset the branch to its base and keep only the change folder
(the queued breakage, tasks unticked) for the ship step. Prints one JSON object.
"""

import json
import os
import pathlib
import subprocess

BASE = os.environ.get("BASE_BRANCH") or "auto"


def git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout.strip()


def pin_back() -> dict:
    name, change = os.environ.get("INPUTS_PLUGIN", ""), os.environ.get("INPUTS_CHANGE", "")
    if os.environ.get("INPUTS_MERGED", "").strip().lower() == "true":
        return {"pinned": False, "attempt": "", "message": ""}
    folder = f"openspec/changes/{change}"
    branch = git("rev-parse", "--abbrev-ref", "HEAD")
    git("add", "-A")
    if git("status", "--porcelain"):
        git("commit", "-m", f"wip: unfinished adaptation to {name}")
    attempt = f"{branch}-attempt"
    git("branch", "-f", attempt, "HEAD")
    git("reset", "--hard", git("merge-base", "HEAD", BASE))
    git("checkout", attempt, "--", folder)
    tasks = pathlib.Path(folder) / "tasks.md"
    if tasks.exists():
        tasks.write_text(tasks.read_text().replace("- [x]", "- [ ]"))
    proposal = pathlib.Path(folder) / "proposal.md"
    proposal.write_text(
        proposal.read_text().rstrip()
        + f"\n\n## Status\n\nPinned back in lazy-lock.json: the fix loop did not ship. The unfinished attempt is"
        f" on branch `{attempt}`. Resume with `make update PLUGIN={name}`.\n"
    )
    return {"pinned": True, "attempt": attempt, "message": f"chore(deps): keep {name} pinned, queue {change}"}


print(json.dumps(pin_back()))
