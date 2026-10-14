"""The work-queue `meta` node picks a queued change's openspec schema before the spec step, so the agent
never does (it spent turns on `openspec instructions design` and schema.yaml, then switched schemas itself).
A change needs design.md only for a new or changed look: a feature (`Kind: feature`), or a proposal.md or
design.md holding a render section. Every other change, and every `skip_specs: true` one, gets the
repo-local schema `spec-driven-no-design` (proposal → specs → tasks, openspec/schemas/), so `openspec
status` reads complete once tasks.md (and any spec delta) exists; a change needing design gets
`spec-driven`.

As a script: prints {skip_specs, design} for INPUTS_CHANGE under LOOP_CHANGES_DIR (fixtures) or
openspec/changes; the `classify` node answers visible_ui and architecture after the spec step.
"""

import json
import os
import pathlib
import re
import subprocess

from tasks import has_render

SCHEMA = "spec-driven-no-design"
DESIGN_SCHEMA = "spec-driven"
FEATURE = re.compile(r"^Kind:\s*feature\b", re.MULTILINE | re.IGNORECASE)
SKIP = re.compile(r"^skip_specs:\s*true\s*$", re.MULTILINE)
SCHEMA_LINE = re.compile(r"^schema:.*$", re.MULTILINE)


def changes_dir() -> pathlib.Path:
    return pathlib.Path(os.environ.get("LOOP_CHANGES_DIR") or "openspec/changes")


def needs_design(folder: pathlib.Path) -> bool:
    """A feature, or a proposal.md / design.md with a render section: the change draws a new look."""
    proposal = folder / "proposal.md"
    text = proposal.read_text() if proposal.is_file() else ""
    return FEATURE.search(text) is not None or has_render(proposal) or has_render(folder / "design.md")


def set_schema(meta: pathlib.Path, schema: str) -> None:
    """Write `schema:` into the change's metadata, committing only an actual switch."""
    text = meta.read_text() if meta.exists() else ""
    line = f"schema: {schema}"
    updated = SCHEMA_LINE.sub(line, text, count=1) if SCHEMA_LINE.search(text) else f"{line}\n{text}"
    if updated != text:
        meta.write_text(updated)
        commit(meta, schema)


def commit(meta: pathlib.Path, schema: str) -> None:
    """Commit the schema switch on its own, so it never rides along in the next step's commit (fixture
    runs, which point LOOP_CHANGES_DIR elsewhere, commit nothing)."""
    if os.environ.get("LOOP_CHANGES_DIR"):
        return
    subprocess.run(["git", "add", "--", str(meta)], capture_output=True)
    name = "no-design" if schema == SCHEMA else "design"
    message = f"chore(openspec): {meta.parent.name} uses the {name} schema"
    subprocess.run(["git", "commit", "-q", "-m", message, "--", str(meta)], capture_output=True)


def pick_schema(folder: pathlib.Path) -> dict[str, bool]:
    meta = folder / ".openspec.yaml"
    skip = SKIP.search(meta.read_text() if meta.exists() else "") is not None
    design = not skip and needs_design(folder)
    if folder.is_dir():
        set_schema(meta, DESIGN_SCHEMA if design else SCHEMA)
    return {"skip_specs": skip, "design": design}


def main() -> None:
    change = os.environ.get("INPUTS_CHANGE", "")
    result = pick_schema(changes_dir() / change) if change else {"skip_specs": False, "design": False}
    print(json.dumps(result))


if __name__ == "__main__":
    main()
