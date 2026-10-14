"""Context pack for one change: everything an agent step needs, gathered once into
$ARTIFACTS_DIR/context.md so steps read one file instead of exploring the repo (docs/workflow.md,
Steps). Holds the root cause's `## Evidence` (proposal.md: file:line refs or probe output, so agents
do not re-read what it covers), the change artifacts, the Loop lessons, the files the next task names and the
failures of the last gate. Only what the next task needs: a test file keeps only the cases the task names (its
`<capability>: <scenario>` names), a doc only the `## ` sections the task names (an outline of the rest), other
files the change names are listed, not inlined, a spec delta keeps the requirements of the task's scenarios, and a proposal's `## Unblocked` (or a blocked `## Rejected run`)
is dropped once no `## Blocked` section is left. Prints {"has_task", "context"}: has_task is false when no task is left
(or tasks.md is blocked), so the task loop skips its implement session.
"""

import json
import os
import pathlib
import re

from blocked import SECTION as BLOCKED, blocks
from tasks import next_task

CHANGE = os.environ.get("INPUTS_CHANGE", "")
ARTIFACTS = pathlib.Path(os.environ.get("ARTIFACTS_DIR", ".")).resolve()
FILE_LINES = 300  # per referenced file
TOTAL_LINES = 2500  # all referenced files together
CASE_NAME = re.compile(r"`([\w-]+: [^`]+)`")
CASE_LINE = re.compile(r'^T\["([^"]+)"\]')
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


def drop_section(text: str, title: str) -> str:
    return re.sub(rf"^## {title}\n(?:(?!## ).*\n?)*", "", text, flags=re.MULTILINE)


def current_proposal(text: str, blocked: bool) -> str:
    """proposal.md without what no longer applies once nothing is blocked: the `## Unblocked` guidance, and a
    `## Rejected run` whose every reason was the block."""
    if blocked:
        return text
    rejected = re.search(r"^## Rejected run\n(.*?)(?=^## |\Z)", text, re.MULTILINE | re.DOTALL)
    reasons = [line for line in rejected.group(1).splitlines() if line.startswith("- ")] if rejected else []
    if reasons and reasons[0].startswith("- blocked:"):  # the judge lists reject reasons first: only the block
        text = drop_section(text, "Rejected run")
    return drop_section(text, "Unblocked")


def delta_requirements(text: str, task: str) -> str:
    """A spec delta with only the requirements holding a scenario the task names (all when it names none)."""
    titles = {name.split(": ", 1)[1] for name in CASE_NAME.findall(task)}
    blocks = re.split(r"(?m)^(?=### Requirement:)", text)
    named = [b for b in blocks[1:] if set(re.findall(r"(?m)^#### Scenario:\s*(.+?)\s*$", b)) & titles]
    if not named:
        return text
    others = ["- " + b.splitlines()[0].removeprefix("### ") for b in blocks[1:] if b not in named]
    return "".join([blocks[0], *named]) + ("\nOther requirements (not this task's):\n" + "\n".join(others) if others else "")


def change_artifacts(change_dir: pathlib.Path, task: str) -> list[str]:
    parts = []
    texts = {name: (change_dir / name).read_text() for name in ("proposal.md", "design.md", "tasks.md") if (change_dir / name).exists()}
    blocked = any(BLOCKED.search(text) and blocks(text) for text in texts.values())
    for name, text in texts.items():
        parts.append(section(f"{change_dir.name}/{name}", current_proposal(text, blocked) if name == "proposal.md" else text))
    for spec in sorted((change_dir / "specs").glob("*/spec.md")):
        parts.append(section(f"spec delta: {spec.parent.name}", delta_requirements(spec.read_text(), task)))
    return parts


def test_cases(lines: list[str], wanted: set[str]) -> list[str]:
    """A test file's header (up to its first case) and the top-level cases named in `wanted`."""
    starts = [i for i, line in enumerate(lines) if CASE_LINE.match(line) or line.startswith("return ")]
    if not starts:
        return lines
    kept = lines[: starts[0]]
    for a, b in zip(starts, starts[1:] + [len(lines)]):
        case = CASE_LINE.match(lines[a])
        if case and case.group(1) in wanted:
            kept += lines[a:b]
    omitted = sum(1 for i in starts if (m := CASE_LINE.match(lines[i])) and m.group(1) not in wanted)
    return kept + ([f"-- … {omitted} other cases not shown (not this task's)"] if omitted else [])


def doc_sections(lines: list[str], task: str) -> list[str]:
    """The `## ` sections of a doc whose title the task names, and an outline of the others."""
    starts = [i for i, line in enumerate(lines) if line.startswith("## ")] + [len(lines)]
    kept, outline = lines[: starts[0]][:5], []
    for a, b in zip(starts, starts[1:]):
        title = lines[a][3:].strip().lower()
        if title in task or title.rstrip("s") in task:
            kept += lines[a:b]
        else:
            outline.append(f"{lines[a]}  (line {a + 1})")
    return kept + (["", "Other sections (read a range when needed):", *outline] if outline else [])


def referenced_files(change_dir: pathlib.Path, task: str, evidence: str) -> list[str]:
    """Files the next task (or the Evidence) names, narrowed to what it needs; the other files the change names
    are listed by path."""
    text = "\n".join(p.read_text() for p in change_dir.glob("*.md"))
    named, wanted = set(PATH_RE.findall(task + "\n" + evidence)), set(CASE_NAME.findall(task))
    seen, parts, others, budget = set(), [], [], TOTAL_LINES
    for path in PATH_RE.findall(text) + sorted(named):
        file = pathlib.Path(path)
        if path in seen or not file.is_file():
            continue
        seen.add(path)
        if path not in named or budget <= 0:
            others.append(f"- `{path}`")
            continue
        lines = file.read_text(errors="replace").splitlines()
        if path.startswith("tests/") and path.endswith(".lua"):
            lines = test_cases(lines, wanted)
        elif path.endswith(".md"):
            lines = doc_sections(lines, task.lower())
        shown = lines[: min(FILE_LINES, budget)]
        budget -= len(shown)
        more = f"\n… {len(lines) - len(shown)} more lines" if len(shown) < len(lines) else ""
        parts.append(section(f"file: {path}", "```\n" + "\n".join(shown) + more + "\n```"))
    if others:
        parts.append(section("Other files the change names (not inlined: read a range when needed)", "\n".join(others)))
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
    parts += change_artifacts(change_dir, task)
    plugins = plugin_sources(change_dir)
    if plugins:
        parts.append(section("Installed plugin sources", plugins))
    failures = last_failures()
    if failures:
        parts.append(section("Last gate failures", failures))
    parts += referenced_files(change_dir, task, found)
    (ARTIFACTS / "change").write_text(CHANGE)  # until_bash gets no INPUTS_* env; tasks.py reads this
    out = ARTIFACTS / "context.md"
    out.write_text("\n".join(parts))
    print(json.dumps({"has_task": has_task(change_dir / "tasks.md", task), "context": str(out)}))


if __name__ == "__main__":
    main()
