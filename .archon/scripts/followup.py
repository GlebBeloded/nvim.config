"""After a rejected run: re-queue the work on `auto` (under the ship lock) so `make queue`/`make drain`
picks it up again from the kept branch. When `<change>` is still active on `auto`, its proposal gets
`Adopt: <branch>` and a `## Rejected run` section with the judge's reasons (no second change for the
same work); otherwise a follow-up change `followup-<change>` is queued. No AI. Prints {queued, change}.
"""

import json
import os
import re
import shutil
import subprocess
import tempfile

from shiplock import acquire_lock, lock_path, release_lock

BASE = os.environ.get("BASE_BRANCH") or "auto"
change = os.environ.get("INPUTS_CHANGE", "") or "change"
reasons = os.environ.get("INPUTS_REASONS", "").strip() or "- unknown"


def git(*args: str, cwd: str | None = None) -> str:
    return subprocess.run(
        ["git", *args], cwd=cwd, capture_output=True, text=True, check=True
    ).stdout.strip()


def base_checkout() -> str | None:
    path = None
    for line in git("worktree", "list", "--porcelain").splitlines():
        if line.startswith("worktree "):
            path = line.removeprefix("worktree ")
        elif line == f"branch refs/heads/{BASE}":
            return path
    return None


def write_change(root: str, name: str, branch: str) -> None:
    folder = os.path.join(root, "openspec/changes", name)
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, ".openspec.yaml"), "w") as f:
        f.write(
            "schema: spec-driven\nskip_specs: true\n"
        )  # a follow-up fixes reasons; spec adds a delta if it must
    with open(os.path.join(folder, "proposal.md"), "w") as f:
        f.write(
            f"## Why\nRun on `{branch}` for `{change}` was rejected by the judge:\n{reasons}\n\nKind: bug\nAdopt: {branch}\n\n"
            f"## What Changes\n- Continue from branch `{branch}`: merge it, fix the reasons above, ship.\n\n"
            f"## Impact\n- Same scope as `{change}`. Out of scope: anything else.\n"
        )


def set_adopt(text: str, branch: str) -> str:
    """`text` with one `Adopt: <branch>` line: in place of the first existing one, else after the
    `Kind:` line, else at the end of `## Why`, else at the end."""
    adopt = f"Adopt: {branch}"
    lines = text.splitlines()
    found = [i for i, line in enumerate(lines) if line.startswith("Adopt:")]
    if found:
        lines[found[0]] = adopt
        return (
            "\n".join(line for i, line in enumerate(lines) if i not in found[1:]) + "\n"
        )
    kind = next((i for i, line in enumerate(lines) if line.startswith("Kind:")), None)
    if kind is not None:
        lines.insert(kind + 1, adopt)
        return "\n".join(lines) + "\n"
    why = next((i for i, line in enumerate(lines) if line.strip() == "## Why"), None)
    if why is None:
        return "\n".join([*lines, "", adopt]).lstrip("\n") + "\n"
    end = next(
        (i for i in range(why + 1, len(lines)) if lines[i].startswith("## ")),
        len(lines),
    )
    while end > why + 1 and not lines[end - 1].strip():
        end -= 1
    lines[end:end] = ["", adopt]
    return "\n".join(lines) + "\n"


def set_rejected(text: str, branch: str) -> str:
    """`text` with its `## Rejected run` section (if any) replaced by one for `branch` at the end."""
    text = re.sub(r"^## Rejected run\n(?:(?!## ).*\n?)*", "", text, flags=re.M).rstrip(
        "\n"
    )
    return f"{text}\n\n## Rejected run\nRun on `{branch}` was rejected by the judge:\n{reasons}\n"


def requeue(root: str, branch: str) -> None:
    path = os.path.join(root, "openspec/changes", change, "proposal.md")
    with open(path) as f:
        text = f.read()
    with open(path, "w") as f:
        f.write(set_rejected(set_adopt(text, branch), branch))


def registered(path: str) -> bool:
    real = os.path.realpath(path)
    return any(
        line.startswith("worktree ") and os.path.realpath(line.removeprefix("worktree ")) == real
        for line in git("worktree", "list", "--porcelain").splitlines()
    )


def queue(root: str) -> str:
    """Writes and commits the re-queued change in `root` (a checkout of BASE); returns its name."""
    if os.path.isfile(os.path.join(root, "openspec/changes", change, "proposal.md")):
        requeue(root, branch)
        name, message = change, f"chore(openspec): re-queue {change} from {branch}"
    else:
        name = default_name
        write_change(root, name, branch)
        message = f"chore(openspec): queue {name}"
    git("add", "openspec/changes/" + name, cwd=root)
    git("commit", "-q", "-m", message, cwd=root)
    return name


def queue_detached() -> str:
    """`queue` in a temp worktree of BASE, then moves BASE to its commit. The worktree is removed on
    every exit: a failing post-checkout hook fails `worktree add` after Git registered it."""
    temp = tempfile.mkdtemp(prefix="nvim-followup-")
    try:
        git("worktree", "add", "--detach", temp, BASE)
        name = queue(temp)
        git("update-ref", f"refs/heads/{BASE}", git("rev-parse", "HEAD", cwd=temp))
        return name
    finally:
        if registered(temp):
            git("worktree", "remove", "--force", temp)
        shutil.rmtree(temp, ignore_errors=True)


branch = git("rev-parse", "--abbrev-ref", "HEAD")
default_name = f"followup-{change}"[:60]
lock = lock_path()
acquire_lock(lock, 600)
try:
    target = base_checkout()
    if target is not None and git("status", "--porcelain", "--untracked-files=no", cwd=target):
        print(json.dumps({"queued": False, "change": default_name, "reason": f"{target} has uncommitted changes"}))
        raise SystemExit(0)
    name = queue(target) if target is not None else queue_detached()
finally:
    release_lock(lock)
print(json.dumps({"queued": True, "change": name}))
