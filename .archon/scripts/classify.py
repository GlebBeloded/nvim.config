"""Work-queue `classify` node: answers {visible_ui, architecture} for a specified change from its files,
so the spec step runs without a JSON schema (a forced schema made the agent print it every turn).

visible_ui: design.md holds a render section (queue-spec writes design.md with renders only for a new or
changed look). architecture: proposal.md `## Impact` or tasks.md names a plugin wiring or load-order file
(lua/gleb/plugins/, the root init.lua, lazy-lock.json) or docs/architecture.md. A skip_specs change is
neither. INPUTS_CHANGE under LOOP_CHANGES_DIR (fixtures) or openspec/changes.
"""

import json
import os
import pathlib
import re

from no_design import SKIP
from tasks import has_render

IMPACT = re.compile(r"^## Impact\b.*?(?=^## |\Z)", re.MULTILINE | re.DOTALL)
WIRING = re.compile(r"lua/gleb/plugins/|(?<![\w/.-])init\.lua\b|lazy-lock\.json|docs/architecture\.md")


def changes_dir() -> pathlib.Path:
    return pathlib.Path(os.environ.get("LOOP_CHANGES_DIR") or "openspec/changes")


def read(path: pathlib.Path) -> str:
    return path.read_text() if path.is_file() else ""


def touches_wiring(folder: pathlib.Path) -> bool:
    """proposal.md's Impact section or tasks.md names a wiring or load-order file."""
    impact = IMPACT.search(read(folder / "proposal.md"))
    text = (impact.group(0) if impact else "") + "\n" + read(folder / "tasks.md")
    return WIRING.search(text) is not None


def classify(folder: pathlib.Path) -> dict[str, bool]:
    if SKIP.search(read(folder / ".openspec.yaml")):
        return {"visible_ui": False, "architecture": False}
    return {"visible_ui": has_render(folder / "design.md"), "architecture": touches_wiring(folder)}


if __name__ == "__main__":
    print(json.dumps(classify(changes_dir() / os.environ.get("INPUTS_CHANGE", ""))))
