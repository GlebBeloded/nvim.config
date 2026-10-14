"""Main-spec scenarios a change pins but does not plan: no AI.

Touched symbols are the backticked config identifiers and keymap lhs in proposal.md `## What Changes`
and `## Impact` (kept only when the config, `lua/`, `init.lua` or `terminal/`, holds them), plus, on a
branch, the lhs and callables of changed `vim.keymap.set(`/`map(` lines and `local function` names in
`git diff <merge-base> -U0 -- lua/ init.lua`. Each `openspec/specs/*/spec.md` scenario (or requirement
prose, when none of its scenarios hits) naming one is pinned, unless its capability has a delta in the
change or `## Impact` names its title. A bare lhs pins only a line that presses or reads the mapping
and is no enumeration (a desc list).

Usage: pinned.py [--check] <change>. Prints `<capability>: <scenario> (<spec>:<line>)` per pin, or
`none`; `--check` exits 1 when any. LOOP_CHANGES_DIR overrides openspec/changes (fixtures),
BASE_BRANCH the base (auto).
"""

import os
import pathlib
import re
import subprocess
import sys

BASE = os.environ.get("BASE_BRANCH") or "auto"
CONFIG = ("lua", "init.lua", "terminal")
SPAN = re.compile(r"`([^`\n]+)`")
STRING = re.compile(r"\"(?:[^\"\\]|\\.)*\"|'(?:[^'\\]|\\.)*'")
IDENT = re.compile(r"[A-Za-z_]\w*(?:[.:][A-Za-z_]\w*)*")
LHS = re.compile(r"<[A-Za-z][\w-]*>\S*|\S*<[A-Za-z][\w-]*>|[\w\[\]]{1,3}")
MAP_CALL = re.compile(r"\b(?:vim\.keymap\.set|map)\(\s*(.*)")
LOCAL_FN = re.compile(r"\blocal\s+function\s+([A-Za-z_]\w*)")
KEY_USE = re.compile(r"\b(?:press(?:ed|es)?|typed?|maparg|feedkeys)\b")
# Lua and Neovim plumbing every module uses: naming it pins nothing (`package.loaded`, `vim.fn.x`)
GENERIC = re.compile(r"(?:package|string|table|math|os|io|vim\.(?:fn|api|o|opt|bo|wo|g|b|w|v|env|uv|loop|fs))\.|vim\.(?:tbl|list)_")
ENUMERATION = 8  # a line with more backticked spans than this lists names (e.g. every desc), it pins nothing
STOP = {
    "and", "buffer", "desc", "end", "expr", "false", "function", "keymap", "local", "map", "nil", "noremap",
    "not", "opts", "or", "remap", "require", "return", "self", "set", "silent", "true", "vim",
}


def section(text: str, title: str) -> str:
    m = re.search(rf"^## {title}\s*$(.*?)(?=^## |\Z)", text, re.MULTILINE | re.DOTALL)
    return m.group(1) if m else ""


def config_text(root: pathlib.Path) -> str:
    files = []
    for name in CONFIG:
        path = root / name
        files += [path] if path.is_file() else [p for p in path.rglob("*") if p.is_file()] if path.is_dir() else []
    return "\n".join(p.read_text(errors="replace") for p in files)


def strong(name: str) -> bool:
    """A name specific enough to grep alone: dotted, snake_case or camelCase."""
    return name.lower() not in STOP and not GENERIC.match(name) and bool(re.search(r"[._:]|[a-z][A-Z]", name))


def proposal_symbols(proposal: str, config: str) -> tuple[set[str], set[str]]:
    """(lhs, identifiers) named in What Changes / Impact that the config holds."""
    lhs, idents = set(), set()
    for span in SPAN.findall(section(proposal, "What Changes") + section(proposal, "Impact")):
        span = span.strip()
        if "/" in span or re.search(r"\.(lua|md|sh|py|ya?ml|json|toml|kdl)$", span):
            continue  # a path
        if LHS.fullmatch(span):
            if f'"{span}"' in config:
                lhs.add(span)
            continue
        for name in IDENT.findall(STRING.sub(lambda s: " " + s.group(0)[1:-1] + " ", span)):
            if strong(name) and name in config:
                idents.add(name)
    return lhs, idents


def git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout


def branch_diff() -> str:
    try:
        base = git("merge-base", "HEAD", BASE).strip()
        return git("diff", base, "-U0", "--", "lua/", "init.lua")
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""


def map_lhs(args: str) -> tuple[str, str] | None:
    """(lhs, the call with string literals blanked) of a `map(`/`vim.keymap.set(` argument list."""
    rest = args[args.index("}") + 1 :] if args.startswith("{") and "}" in args else STRING.sub("", args, count=1)
    m = STRING.search(rest)
    return (m.group(0)[1:-1], STRING.sub('""', rest[m.end() :])) if m else None


def diff_symbols(diff: str) -> tuple[set[str], set[str]]:
    """(lhs, identifiers) of mappings whose call changed (not only a string such as desc) and of
    `local function` lines the diff adds or removes."""
    calls: dict[str, dict[str, set[str]]] = {}
    idents: set[str] = set()
    for line in diff.splitlines():
        if line[:1] not in "+-" or line.startswith(("+++", "---")):
            continue
        idents |= set(LOCAL_FN.findall(line))
        m = MAP_CALL.search(line)
        parsed = map_lhs(m.group(1).strip()) if m else None
        if parsed:
            calls.setdefault(parsed[0], {"+": set(), "-": set()})[line[0]].add(parsed[1].strip())
    lhs = set()
    for key, sides in calls.items():
        if sides["+"] == sides["-"]:
            continue  # moved, or only a string (desc) changed
        lhs.add(key)
        old = {n for c in sides["-"] for n in IDENT.findall(c)}
        new = {n for c in sides["+"] for n in IDENT.findall(c)}
        idents |= {n for n in old ^ new if n.lower() not in STOP}
    return lhs, idents


def hits(line: str, lhs: set[str], idents: set[str]) -> bool:
    for name in idents:
        if (name in line) if strong(name) else any(f in line for f in (f"`{name}`", f"`{name}(", f".{name}`", f".{name}(")):
            return True
    if len(SPAN.findall(line)) > ENUMERATION or not KEY_USE.search(line):
        return False
    return any(f"`{k}`" in line or f'"{k}"' in line for k in lhs)


def spec_pins(spec: pathlib.Path, lhs: set[str], idents: set[str]) -> list[tuple[str, int]]:
    """(title, line) of each pinned scenario; a requirement whose prose hits and none of whose scenarios
    does is listed as `Requirement: <name>`."""
    pins: list[tuple[str, int]] = []
    req = scen = None
    req_hit = scen_hit = False

    def close_scenario() -> None:
        nonlocal scen, scen_hit
        if scen and scen_hit:
            pins.append(scen)
        scen, scen_hit = None, False

    def close_requirement() -> None:
        nonlocal req, req_hit
        close_scenario()
        if req and req_hit and len(pins) == req_pins:  # its scenarios name nothing
            pins.append((f"Requirement: {req[0]}", req[1]))
        req, req_hit = None, False

    req_pins = 0
    for number, line in enumerate(spec.read_text().splitlines(), 1):
        if line.startswith("### Requirement:") or line.startswith("## "):
            close_requirement()
            req_pins = len(pins)
            if line.startswith("### "):
                req = (line.split(":", 1)[1].strip(), number)
            continue
        if line.startswith("#### Scenario:"):
            close_scenario()
            scen = (line.split(":", 1)[1].strip(), number)
        if hits(line, lhs, idents):
            if scen:
                scen_hit = True
            elif req:
                req_hit = True
    close_requirement()
    return pins


def pinned(change: str) -> list[str]:
    folder = pathlib.Path(os.environ.get("LOOP_CHANGES_DIR") or "openspec/changes") / change
    proposal_path = folder / "proposal.md"
    proposal = proposal_path.read_text() if change and proposal_path.is_file() else ""
    if not proposal:
        return []
    lhs, idents = proposal_symbols(proposal, config_text(pathlib.Path(".")))
    more_lhs, more_idents = diff_symbols(branch_diff())
    lhs, idents = lhs | more_lhs, idents | more_idents
    impact = section(proposal, "Impact")
    out = []
    for spec in sorted(pathlib.Path("openspec/specs").glob("*/spec.md")):
        capability = spec.parent.name
        if (folder / "specs" / capability / "spec.md").is_file():
            continue
        for title, line in spec_pins(spec, lhs, idents):
            if title.removeprefix("Requirement: ") not in impact:
                out.append(f"{capability}: {title} ({spec}:{line})")
    return out


if __name__ == "__main__":
    args = sys.argv[1:]
    check = "--check" in args
    names = [a for a in args if a != "--check"]
    found = pinned(names[0] if names else "")
    if check and found:
        print(
            "pinned scenarios with no delta and no Impact line (each needs a MODIFIED delta restated to the new"
            " behaviour, or one line in proposal.md `## Impact` naming it and why it still holds):"
        )
        print("\n".join("- " + p for p in found))
    elif not check:
        print("\n".join(found) or "none")
    sys.exit(1 if check and found else 0)
