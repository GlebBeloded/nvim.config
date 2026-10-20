"""Pick the next queue item: an active change in openspec/changes/ (archive excluded). Uses
INPUTS_CHANGE when given, otherwise the oldest change (by `created` in .openspec.yaml, then name)
that has no `loop/<change>` branch yet (a branch means a run already took it); a `Priority: high` line in proposal.md
goes first. `update-<plugin>`
changes are skipped: they need the new plugin commit, so `make update PLUGIN=<plugin>` works them.
A change whose proposal.md has a `Depends: <change>[, <change>...]` line waits (even when named)
until each of those changes is archived. QUEUE_SKIP (space- or comma-separated) excludes changes
from an automatic pick (`drain.py` passes the ones it already ran).
Kind: a `Kind: feature` line in proposal.md, or an add-/feat-/new- prefix, makes it a feature;
everything else is a bug fix.
"""

import json
import os
import pathlib
import re
import subprocess
import sys

CHANGES = pathlib.Path("openspec/changes")


def live_run(name: str) -> bool:
    """A running or paused Archon run works this change (an abandoned run's branch does not count)."""
    db = pathlib.Path(os.environ.get("ARCHON_DB") or pathlib.Path.home() / ".archon" / "archon.db")
    if not db.exists():
        return False
    import sqlite3

    query = "select count(*) from remote_agent_workflow_runs where status in ('running','paused') and user_message = ?"
    return sqlite3.connect(db).execute(query, (f"Work queued change {name}",)).fetchone()[0] > 0


def taken(name: str) -> bool:
    ref = f"refs/heads/loop/{name}"
    exists = subprocess.run(["git", "rev-parse", "--verify", "--quiet", ref], stdout=subprocess.DEVNULL).returncode == 0
    return exists and live_run(name)


def created(path: pathlib.Path) -> str:
    meta = path / ".openspec.yaml"
    match = re.search(r"created:\s*(\S+)", meta.read_text()) if meta.exists() else None
    return match.group(1) if match else "9999"


def depends(path: pathlib.Path) -> list[str]:
    proposal = path / "proposal.md"
    text = proposal.read_text() if proposal.exists() else ""
    lines = re.findall(r"^Depends:\s*(.+)$", text, re.M)
    return [name for line in lines for name in re.split(r"[\s,]+", line.strip()) if name]


def archived(name: str) -> bool:
    archive = CHANGES / "archive"
    pattern = re.compile(rf"(\d{{4}}-\d{{2}}-\d{{2}}-)?{re.escape(name)}")
    return archive.is_dir() and any(entry.is_dir() and pattern.fullmatch(entry.name) for entry in archive.iterdir())


def waits_for(name: str) -> list[str]:
    """Dependencies of `name` that are not archived yet."""
    return [dep for dep in depends(CHANGES / name) if not archived(dep)]


def high(path: pathlib.Path) -> bool:
    """A `Priority: high` line in proposal.md: picked before every other change (loop infrastructure fixes)."""
    proposal = path / "proposal.md"
    return proposal.exists() and re.search(r"^Priority:\s*high\b", proposal.read_text(), re.M | re.I) is not None


def kind(path: pathlib.Path) -> str:
    proposal = path / "proposal.md"
    text = proposal.read_text() if proposal.exists() else ""
    match = re.search(r"^Kind:\s*(bug|feature)", text, re.M | re.I)
    if match:
        return match.group(1).lower()
    return "feature" if re.match(r"(add|feat|new)-", path.name) else "bug"


wanted = os.environ.get("INPUTS_CHANGE", "").strip()
listing = json.loads(subprocess.run(["openspec", "list", "--json"], capture_output=True, text=True, check=True).stdout)
# a folder with no proposal.md (an archived change's ignored drafts/ left behind) is not a queued change
names = [c["name"] for c in listing.get("changes", []) if (CHANGES / c["name"] / "proposal.md").exists() and not archived(c["name"])]
skip = set(re.split(r"[\s,]+", os.environ.get("QUEUE_SKIP", "").strip())) - {""}
if wanted:
    candidates = [n for n in names if n == wanted]
    if candidates and waits_for(wanted):
        print(f"queue_pick: {wanted} waits for: {', '.join(waits_for(wanted))}", file=sys.stderr)
        candidates = []
else:
    pending = (n for n in names if not n.startswith("update-") and n not in skip and not taken(n) and not waits_for(n))
    candidates = sorted(pending, key=lambda n: (not high(CHANGES / n), created(CHANGES / n), n))

# changes an automatic pick passes over only for a `Depends:` change not archived yet (drain.py's lanes wait for them)
waiting = [] if wanted else [n for n in names if not n.startswith("update-") and n not in skip and not taken(n) and waits_for(n)]
if not candidates:
    print(json.dumps({"found": False, "change": "", "kind": "", "has_tasks": False, "waiting": waiting}))
else:
    path = CHANGES / candidates[0]
    print(
        json.dumps(
            {
                "found": True,
                "change": path.name,
                "kind": kind(path),
                "has_tasks": (path / "tasks.md").exists(),
                "waiting": waiting,
            }
        )
    )
