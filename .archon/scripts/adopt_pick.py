"""`make queue`'s adopt choice, no AI: of the change's earlier run branches (`loop/<id>`, `loop/<id>-<stamp>`
and the proposal's `Adopt:` line), the one with the most own (non-merge) commits ahead of auto, the `Adopt:` one
and then the newest on a tie, so an abandoned or cancelled later run never loses its work to an older branch.

Usage: adopt_pick.py <change>. Prints the branch, or nothing when the change has none.
"""

import os
import re
import subprocess
import sys

BASE = os.environ.get("BASE_BRANCH") or "auto"


def git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True).stdout.strip()


def named(change: str) -> str:
    """The proposal's first `Adopt:` branch (a follow-up's rejected run), when it exists."""
    proposal = os.path.join(os.environ.get("LOOP_CHANGES_DIR") or "openspec/changes", change, "proposal.md")
    found = re.search(r"(?m)^Adopt: *(\S+)", open(proposal).read()) if os.path.isfile(proposal) else None
    return found.group(1) if found and git("rev-parse", "--verify", "--quiet", f"refs/heads/{found.group(1)}") else ""


def candidates(change: str) -> set[str]:
    refs = git("for-each-ref", "--format=%(refname:short)", f"refs/heads/loop/{change}", f"refs/heads/loop/{change}-*")
    found = {r for r in refs.splitlines() if re.fullmatch(rf"loop/{re.escape(change)}(-\d{{8}}-\d{{6}})?", r)}
    return found | ({named(change)} - {""})


def pick(change: str) -> str:
    adopt = named(change)

    def progress(branch: str) -> tuple[int, bool, int]:
        own = git("rev-list", "--count", "--no-merges", f"{BASE}..{branch}")
        return int(own or 0), branch == adopt, int(git("log", "-1", "--format=%ct", branch) or 0)

    found = candidates(change)
    return max(found, key=progress) if found else ""


if __name__ == "__main__":
    print(pick(sys.argv[1] if len(sys.argv) > 1 else ""))
