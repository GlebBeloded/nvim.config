"""A change with `skip_specs: true` in .openspec.yaml changes no behaviour and no look, so it never needs
design.md. The stock spec-driven schema still lists design as the next artifact (`openspec status`:
"Next: openspec instructions design"), which sends the spec agent hunting for a way around it. This
points such a change at the repo-local schema `spec-driven-no-design` (proposal → specs → tasks,
openspec/schemas/), so status reads complete once tasks.md exists. Changes without skip_specs keep
their schema, and with it design.md and the design gate for visible UI.

As a script (work-queue `meta` node): prints {skip_specs, visible_ui, architecture} for INPUTS_CHANGE
under LOOP_CHANGES_DIR (fixtures) or openspec/changes. visible_ui and architecture are false for a
skip_specs change (no look, no wiring); otherwise they are false here and the spec step answers them.
"""

import json
import os
import pathlib
import re
import subprocess

SCHEMA = "spec-driven-no-design"
SKIP = re.compile(r"^skip_specs:\s*true\s*$", re.MULTILINE)
SCHEMA_LINE = re.compile(r"^schema:.*$", re.MULTILINE)


def changes_dir() -> pathlib.Path:
    return pathlib.Path(os.environ.get("LOOP_CHANGES_DIR") or "openspec/changes")


def no_design(meta: pathlib.Path) -> bool:
    """Point a skip_specs change's metadata at the no-design schema; True when it declares skip_specs."""
    text = meta.read_text() if meta.exists() else ""
    if not SKIP.search(text):
        return False
    line = f"schema: {SCHEMA}"
    updated = SCHEMA_LINE.sub(line, text, count=1) if SCHEMA_LINE.search(text) else f"{line}\n{text}"
    if updated != text:
        meta.write_text(updated)
        commit(meta)
    return True


def commit(meta: pathlib.Path) -> None:
    """Commit the schema switch on its own, so it never rides along in the next step's commit (fixture
    runs, which point LOOP_CHANGES_DIR elsewhere, commit nothing)."""
    if os.environ.get("LOOP_CHANGES_DIR"):
        return
    subprocess.run(["git", "add", "--", str(meta)], capture_output=True)
    message = f"chore(openspec): {meta.parent.name} uses the no-design schema"
    subprocess.run(["git", "commit", "-q", "-m", message, "--", str(meta)], capture_output=True)


def main() -> None:
    change = os.environ.get("INPUTS_CHANGE", "")
    skip = bool(change) and no_design(changes_dir() / change / ".openspec.yaml")
    print(json.dumps({"skip_specs": skip, "visible_ui": False, "architecture": False}))


if __name__ == "__main__":
    main()
