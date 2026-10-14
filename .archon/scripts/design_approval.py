"""The design gate asks once per design: when the user approves it, the work-queue `design-record` node
(INPUTS_MODE=record) writes a `## Design approval` section into the change's proposal.md, a
`Design-approved: <sha256 of design.md>` line plus the gate comment, and commits it on the run branch;
followup.py carries the section to `auto` on re-queue. On a later run the `design-approved` node
(INPUTS_MODE=check) prints {approved, decision, feedback}: approved when design.md's hash still matches,
then design-decide takes `approve` and the earlier comment and the gate is skipped; any edit to design.md
asks again. No AI. INPUTS_CHANGE under LOOP_CHANGES_DIR (fixtures) or openspec/changes.
"""

import hashlib
import json
import os
import pathlib
import re
import subprocess

HEAD = "## Design approval"
SECTION = re.compile(r"^## Design approval\n(?:(?!## ).*\n?)*", re.MULTILINE)
LINE = re.compile(r"^Design-approved: ([0-9a-f]{64})$", re.MULTILINE)


def changes_dir() -> pathlib.Path:
    return pathlib.Path(os.environ.get("LOOP_CHANGES_DIR") or "openspec/changes")


def design_hash(folder: pathlib.Path) -> str:
    design = folder / "design.md"
    return hashlib.sha256(design.read_bytes()).hexdigest() if design.is_file() else ""


def section(text: str) -> str:
    """The `## Design approval` section of a proposal (no trailing blank lines), or ""."""
    found = SECTION.search(text)
    return found.group(0).rstrip("\n") if found else ""


def approval(text: str) -> tuple[str, str]:
    """(sha, comment) recorded in a proposal; ("", "") when there is none."""
    body = section(text)
    sha = LINE.search(body)
    if not sha:
        return "", ""
    comment = body[sha.end() :].strip("\n").splitlines()
    return sha.group(1), "\n".join(line.removeprefix("  ") for line in comment).strip()


def render(sha: str, comment: str) -> str:
    lines = [HEAD, f"Design-approved: {sha}", *("  " + line for line in comment.strip().splitlines())]
    return "\n".join(lines)


def set_section(text: str, block: str) -> str:
    """`text` with its approval section replaced by `block` in place; else inserted before `## Rejected run`,
    else before the last section: followup.py appends `## Rejected run` at the end, so the run branch and
    `auto` add the same lines at the same spot and adopt.py merges them without a conflict."""
    if SECTION.search(text):
        return SECTION.sub(lambda _: block + "\n\n", text, count=1).rstrip("\n") + "\n"
    heads = [m.start() for m in re.finditer(r"^## ", text, re.MULTILINE)]
    rejected = re.search(r"^## Rejected run\b", text, re.MULTILINE)
    at = rejected.start() if rejected else heads[-1] if len(heads) > 1 else None
    if at is None:
        return text.rstrip("\n") + "\n\n" + block + "\n"
    return text[:at] + block + "\n\n" + text[at:]


def check(folder: pathlib.Path) -> dict:
    proposal = folder / "proposal.md"
    sha, comment = approval(proposal.read_text()) if proposal.is_file() else ("", "")
    approved = bool(sha) and sha == design_hash(folder)
    return {"approved": approved, "decision": "approve" if approved else "", "feedback": comment if approved else ""}


def record(folder: pathlib.Path, comment: str) -> dict:
    sha, proposal = design_hash(folder), folder / "proposal.md"
    if not sha or not proposal.is_file():
        return {"recorded": False}
    proposal.write_text(set_section(proposal.read_text(), render(sha, comment)))
    message = f"chore(openspec): record design approval of {folder.name}"
    done = subprocess.run(["git", "commit", "-q", "-m", message, "--", str(proposal)], capture_output=True)
    return {"recorded": done.returncode == 0}


if __name__ == "__main__":
    folder = changes_dir() / os.environ.get("INPUTS_CHANGE", "")
    mode = os.environ.get("INPUTS_MODE", "check")
    out = record(folder, os.environ.get("INPUTS_FEEDBACK", "")) if mode == "record" else check(folder)
    print(json.dumps(out))
