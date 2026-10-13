"""work-queue `adopt` node, no AI: merge an abandoned run's branch (INPUTS_ADOPT) into this run's.
Main specs (`openspec/specs/`) change only by archive, so whatever the adopted branch edited there
is reverted to this branch's pre-merge state (also in a conflicted merge, which adopt-resolve then
finishes) and the summary says so. Prints {conflict, summary}.
"""

import json
import os
import subprocess

BASE = os.environ.get("BASE_BRANCH") or "auto"
SPECS = "openspec/specs"


def git(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", *args], capture_output=True, text=True, check=check)


def restore_specs(before: str) -> list[str]:
    """Put SPECS back to `before` in index and work tree; returns the paths that differed."""
    if not git("ls-tree", "-d", before, SPECS).stdout.strip():
        return []
    git("add", "-A", "--", SPECS)
    changed = git("diff", "--cached", "--name-only", before, "--", SPECS).stdout.split()
    if changed:
        git("rm", "-rqf", "--cached", "--", SPECS)
        git("checkout", before, "--", SPECS)
        added = git("ls-files", "--others", "--exclude-standard", "--", SPECS).stdout.split()
        for path in added:
            os.remove(path)
    return changed


def unmerged() -> list[str]:
    return git("diff", "--name-only", "--diff-filter=U").stdout.split()


def adopt(branch: str) -> tuple[bool, str]:
    before = git("rev-parse", "HEAD").stdout.strip()
    merged = git("-c", "merge.conflictStyle=zdiff3", "merge", "--no-edit", branch, check=False).returncode == 0
    reverted = restore_specs(before)
    if not merged and not unmerged():  # every conflict was in a main spec: finish the merge
        merged = git("commit", "-q", "--no-edit", check=False).returncode == 0
    elif merged and reverted:
        git("commit", "-q", "-m", f"chore(openspec): drop main spec edits adopted from {branch}")
    note = f"; reverted its main spec edits ({', '.join(reverted)}): main specs change only by archive" if reverted else ""
    if merged:
        count = len(git("log", "--oneline", f"{BASE}..HEAD", check=False).stdout.splitlines())
        return False, f"adopted {branch}: {count} commits{note}"
    return True, f"conflicts merging {branch} in: {' '.join(unmerged())}{note}"


def main() -> None:
    branch = os.environ.get("INPUTS_ADOPT", "")
    conflict, summary = adopt(branch) if branch else (False, "nothing to adopt")
    print(json.dumps({"conflict": conflict, "summary": summary}))


if __name__ == "__main__":
    main()
