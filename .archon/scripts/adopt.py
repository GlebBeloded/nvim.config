"""work-queue `adopt` node, no AI: merge an abandoned run's branch (INPUTS_ADOPT) into this run's.
Main specs (`openspec/specs/`) change only by archive, so whatever the adopted branch edited there
is reverted to this branch's pre-merge state (also in a conflicted merge, which adopt-resolve then
finishes) and the summary says so. Its edits to a spec's data sections (`## ` sections other than Purpose
and Requirements, e.g. the shortcut table the chain tests read) are kept: archive never writes them, so a
revert would re-break what the branch fixed (run 794e77a2). Prints {conflict, summary}.
"""

import json
import os
import re
import subprocess

BASE = os.environ.get("BASE_BRANCH") or "auto"
SPECS = "openspec/specs"
ARCHIVED = {"Purpose", "Requirements"}  # sections only archive writes


def sections(text: str) -> dict[str, str]:
    """`## <name>` section texts by name (the preamble under ""), in file order."""
    parts = re.split(r"(?m)^(?=## )", text)
    return {(p.splitlines()[0][3:].strip() if p.startswith("## ") else ""): p for p in parts}


def keep_data(before: str, merged: str) -> str:
    """`before` with the merged text of each data section (new ones appended)."""
    old, new = sections(before), sections(merged)
    for name, text in new.items():
        if name and name not in ARCHIVED:
            old[name] = text
    parts = list(old.values())
    return "".join(p if p.endswith("\n") else p + "\n" for p in parts[:-1]) + parts[-1]


def git(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", *args], capture_output=True, text=True, check=check)


def restore_specs(before: str) -> list[str]:
    """Put SPECS back to `before` in index and work tree, keeping data sections; returns the paths reverted."""
    if not git("ls-tree", "-d", before, SPECS).stdout.strip():
        return []
    conflicted = set(unmerged())  # before `add` resolves them
    git("add", "-A", "--", SPECS)
    changed = git("diff", "--cached", "--name-only", before, "--", SPECS).stdout.split()
    if not changed:
        return []
    merged = {p: open(p).read() for p in changed if p not in conflicted and os.path.exists(p)}
    git("rm", "-rqf", "--cached", "--", SPECS)
    git("checkout", before, "--", SPECS)
    added = git("ls-files", "--others", "--exclude-standard", "--", SPECS).stdout.split()
    for path in added:
        os.remove(path)
    reverted = []
    for path in changed:
        if path in merged and os.path.exists(path):
            text = keep_data(open(path).read(), merged[path])
            with open(path, "w") as f:
                f.write(text)
            git("add", "--", path)
            if text == merged[path]:
                continue
        reverted.append(path)
    return reverted


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
