"""Context pack for one change: everything an agent step needs, gathered once into
$ARTIFACTS_DIR/context.md so steps read one file instead of exploring the repo (docs/workflow.md,
Steps). Holds the change artifacts, the Loop lessons, the files tasks.md names (capped) and the
failures of the last gate. Prints the pack path.
"""

import json
import os
import pathlib
import re

from tasks import next_task

CHANGE = os.environ.get("INPUTS_CHANGE", "")
ARTIFACTS = pathlib.Path(os.environ.get("ARTIFACTS_DIR", ".")).resolve()
FILE_LINES = 300  # per referenced file
TOTAL_LINES = 2500  # all referenced files together
PATH_RE = re.compile(r"`((?:lua|tests|plugins|terminal|ops|\.archon|docs)/[\w./-]+\.(?:lua|py|sh|md|yaml|json))(?::\d+)?")


def section(title: str, body: str) -> str:
    return f"## {title}\n\n{body.strip()}\n"


def lessons() -> str:
    text = pathlib.Path("docs/workflow.md").read_text()
    match = re.search(r"^## Loop lessons\n(.*?)(?=^## )", text, re.MULTILINE | re.DOTALL)
    return match.group(1) if match else ""


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


def main() -> None:
    change_dir = pathlib.Path("openspec/changes") / CHANGE
    task = next_task(change_dir / "tasks.md")
    parts = [f"# Context pack: {CHANGE}\n", section("Next task", task or "(none: every task is ticked)")]
    parts.append(section("Loop lessons", lessons()))
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
    print(out)


if __name__ == "__main__":
    main()
