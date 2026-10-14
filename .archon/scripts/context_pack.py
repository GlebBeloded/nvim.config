"""Context pack for one change: everything an agent step needs, gathered once into
$ARTIFACTS_DIR/context.md so steps read one file instead of exploring the repo (docs/workflow.md,
Steps). Holds the root cause's `## Evidence` (proposal.md: file:line refs or probe output, so agents
do not re-read what it covers), the change artifacts, the Loop lessons, the files tasks.md names (capped) and the
failures of the last gate. Prints {"has_task", "context"}: has_task is false when no task is left
(or tasks.md is blocked), so the task loop skips its implement session.
"""

import json
import os
import pathlib
import re

from blocked import blocks
from tasks import next_task

CHANGE = os.environ.get("INPUTS_CHANGE", "")
ARTIFACTS = pathlib.Path(os.environ.get("ARTIFACTS_DIR", ".")).resolve()
FILE_LINES = 300  # per referenced file
TOTAL_LINES = 2500  # all referenced files together
PATH_RE = re.compile(r"`((?:lua|tests|plugins|terminal|ops|\.archon|docs)/[\w./-]+\.(?:lua|py|sh|md|yaml|json))(?::\d+)?")


PROBING = (
    "- `make probe SCRIPT=<file.lua>` (or `PROBE='lua code'`) runs Lua in the tests' full-config child "
    "and sandbox, prints its output and return values, exits non-zero on error (docs/testing.md).\n"
    "- LSP restart and neo-tree renders are async: wait for the end state, not for attachment."
)


def section(title: str, body: str) -> str:
    return f"## {title}\n\n{body.strip()}\n"


def lessons() -> str:
    text = pathlib.Path("docs/workflow.md").read_text()
    match = re.search(r"^## Loop lessons\n(.*?)(?=^## )", text, re.MULTILINE | re.DOTALL)
    return match.group(1) if match else ""


def evidence(change_dir: pathlib.Path) -> str:
    """The `## Evidence` section of the change's proposal.md (a bug's root-cause refs), or ""."""
    proposal = change_dir / "proposal.md"
    text = proposal.read_text() if proposal.exists() else ""
    match = re.search(r"^## Evidence[^\n]*\n(.*?)(?=^## |\Z)", text, re.MULTILINE | re.DOTALL)
    return match.group(1).strip() if match else ""


def change_artifacts(change_dir: pathlib.Path) -> list[str]:
    parts = []
    for name in ("proposal.md", "design.md", "tasks.md"):
        path = change_dir / name
        if path.exists():
            parts.append(section(f"{change_dir.name}/{name}", path.read_text()))
    for spec in sorted((change_dir / "specs").glob("*/spec.md")):
        parts.append(section(f"spec delta: {spec.parent.name}", spec.read_text()))
    return parts


def referenced_files(change_dir: pathlib.Path) -> list[str]:
    text = "\n".join(p.read_text() for p in change_dir.glob("*.md"))
    seen, parts, budget = set(), [], TOTAL_LINES
    for path in PATH_RE.findall(text):
        file = pathlib.Path(path)
        if path in seen or not file.is_file() or budget <= 0:
            continue
        seen.add(path)
        lines = file.read_text(errors="replace").splitlines()
        shown = lines[: min(FILE_LINES, budget)]
        budget -= len(shown)
        more = f"\n… {len(lines) - len(shown)} more lines" if len(shown) < len(lines) else ""
        parts.append(section(f"file: {path}", "```\n" + "\n".join(shown) + more + "\n```"))
    return parts


def plugin_sources(change_dir: pathlib.Path) -> str:
    """Install paths of the lazy.nvim plugins the change mentions, so agents read plugin source there."""
    lock = pathlib.Path("lazy-lock.json")
    if not lock.exists():
        return ""
    text = "\n".join(p.read_text(errors="replace") for p in change_dir.rglob("*.md"))
    data = pathlib.Path(os.environ.get("NVIM_TEST_DATA_DIR") or pathlib.Path.home() / ".local/share/nvim")
    names = [n for n in json.loads(lock.read_text()) if n in text or n.removesuffix(".nvim") in text]
    return "\n".join(f"- {n}: {data / 'lazy' / n}" for n in names)


def last_failures() -> str:
    logs = sorted(ARTIFACTS.glob("check-*.log"), key=lambda p: int(p.stem.split("-")[1]))
    if not logs:
        return ""
    lines = logs[-1].read_text(errors="replace").splitlines()
    return "\n".join(line for line in lines if re.match(r"^(FAIL|check:)", line) or "FAIL in" in line)[:4000]


def has_task(tasks: pathlib.Path, task: str) -> bool:
    return bool(task) and not blocks(tasks.read_text())


def main() -> None:
    change_dir = pathlib.Path("openspec/changes") / CHANGE
    task = next_task(change_dir / "tasks.md")
    parts = [f"# Context pack: {CHANGE}\n", section("Next task", task or "(none: every task is ticked)")]
    found = evidence(change_dir)
    if found:
        parts.append(section("Evidence", found + "\n\n(root cause, proposal.md: do not re-read plugin source these refs cover)"))
    parts.append(section("Loop lessons", lessons()))
    parts.append(section("Probing", PROBING))
    parts += change_artifacts(change_dir)
    plugins = plugin_sources(change_dir)
    if plugins:
        parts.append(section("Installed plugin sources", plugins))
    failures = last_failures()
    if failures:
        parts.append(section("Last gate failures", failures))
    parts += referenced_files(change_dir)
    (ARTIFACTS / "change").write_text(CHANGE)  # until_bash gets no INPUTS_* env; tasks.py reads this
    out = ARTIFACTS / "context.md"
    out.write_text("\n".join(parts))
    print(json.dumps({"has_task": has_task(change_dir / "tasks.md", task), "context": str(out)}))


if __name__ == "__main__":
    main()
