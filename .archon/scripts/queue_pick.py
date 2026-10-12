"""Pick the next queue item: an active change in openspec/changes/ (archive excluded). Uses
INPUTS_CHANGE when given, otherwise the oldest change (by `created` in .openspec.yaml, then name)
that has no `loop/<change>` branch yet (a branch means a run already took it). `update-<plugin>`
changes are skipped: they need the new plugin commit, so `make update PLUGIN=<plugin>` works them.
Kind: a `Kind: feature` line in proposal.md, or an add-/feat-/new- prefix, makes it a feature;
everything else is a bug fix.
"""

import json
import os
import pathlib
import re
import subprocess

CHANGES = pathlib.Path("openspec/changes")


def taken(name: str) -> bool:
    ref = f"refs/heads/loop/{name}"
    return subprocess.run(["git", "rev-parse", "--verify", "--quiet", ref], stdout=subprocess.DEVNULL).returncode == 0


def created(path: pathlib.Path) -> str:
    meta = path / ".openspec.yaml"
    match = re.search(r"created:\s*(\S+)", meta.read_text()) if meta.exists() else None
    return match.group(1) if match else "9999"


def kind(path: pathlib.Path) -> str:
    proposal = path / "proposal.md"
    text = proposal.read_text() if proposal.exists() else ""
    match = re.search(r"^Kind:\s*(bug|feature)", text, re.M | re.I)
    if match:
        return match.group(1).lower()
    return "feature" if re.match(r"(add|feat|new)-", path.name) else "bug"


wanted = os.environ.get("INPUTS_CHANGE", "").strip()
listing = json.loads(subprocess.run(["openspec", "list", "--json"], capture_output=True, text=True, check=True).stdout)
names = [c["name"] for c in listing.get("changes", [])]
if wanted:
    candidates = [n for n in names if n == wanted]
else:
    pending = (n for n in names if not n.startswith("update-") and not taken(n))
    candidates = sorted(pending, key=lambda n: (created(CHANGES / n), n))

if not candidates:
    print(json.dumps({"found": False, "change": "", "kind": "", "has_tasks": False}))
else:
    path = CHANGES / candidates[0]
    print(
        json.dumps(
            {
                "found": True,
                "change": path.name,
                "kind": kind(path),
                "has_tasks": (path / "tasks.md").exists(),
            }
        )
    )
