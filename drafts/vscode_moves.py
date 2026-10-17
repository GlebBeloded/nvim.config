#!/usr/bin/env python3
"""Translate pinned VS Code advanced diff fixtures into Lua move goldens."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


PIN = "5b23ab39"
FIXTURES_PATH = Path("src/vs/editor/test/node/diffing/fixtures")
RANGE = re.compile(r"^\[(\d+),(\d+)\)$")


def lua_string(value: str) -> str:
    escaped: list[str] = []
    for char in value:
        codepoint = ord(char)
        if char == "\\":
            escaped.append("\\\\")
        elif char == '"':
            escaped.append('\\"')
        elif char == "\n":
            escaped.append("\\n")
        elif char == "\r":
            escaped.append("\\r")
        elif char == "\t":
            escaped.append("\\t")
        elif codepoint < 32 or codepoint == 127:
            escaped.append(f"\\{codepoint:03d}")
        else:
            escaped.append(char)
    return '"' + "".join(escaped) + '"'


def line_table(content: str) -> str:
    lines = content.split("\n")
    return "{\n" + "".join(f"\t\t{lua_string(line)},\n" for line in lines) + "\t}"


def line_range(value: str) -> tuple[int, int]:
    match = RANGE.fullmatch(value)
    if match is None:
        raise ValueError(f"unexpected line range: {value}")
    return int(match.group(1)) - 1, int(match.group(2)) - 1


def ranges(items: list[dict[str, object]]) -> str:
    rows = []
    for item in items:
        start1, end1 = line_range(str(item["originalRange"]))
        start2, end2 = line_range(str(item["modifiedRange"]))
        rows.append(f"\t\t{{ {start1}, {end1}, {start2}, {end2} }},\n")
    return "{\n" + "".join(rows) + "\t}"


def render(source: Path, folder: str) -> str:
    data = json.loads(source.read_text(encoding="utf-8"))
    relative_source = FIXTURES_PATH / folder / source.name
    return (
        f"-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at {PIN}:\n"
        f"-- {relative_source.as_posix()}\n"
        "-- Modified: JSON rewritten as Lua data, ranges made 0-based.\n"
        "return {\n"
        f"\tlines1 = {line_table(data['original']['content'])},\n"
        f"\tlines2 = {line_table(data['modified']['content'])},\n"
        f"\ttrim_ws = {str('trimws' in folder).lower()},\n"
        f"\tchanges = {ranges(data['diffs'])},\n"
        f"\tmoves = {ranges(data.get('moves', []))},\n"
        "}\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("vscode", type=Path, help="VS Code checkout at the pinned commit")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("tests/unit/diff/fixtures/vscode_moves"),
    )
    args = parser.parse_args()

    fixture_root = args.vscode / FIXTURES_PATH
    sources = sorted(fixture_root.glob("*/advanced.expected.diff.json"))
    if len(sources) != 58:
        raise SystemExit(f"expected 58 fixtures, found {len(sources)}")

    args.output.mkdir(parents=True, exist_ok=True)
    for source in sources:
        folder = source.parent.name
        (args.output / f"{folder}.lua").write_text(render(source, folder), encoding="utf-8")


if __name__ == "__main__":
    main()
