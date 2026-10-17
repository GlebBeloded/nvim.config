#!/usr/bin/env python3
"""Generate the Unicode tables used by the Lua diff tokenizer."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


LETTER_CATEGORIES = {"Lu", "Ll", "Lt", "Lm", "Lo", "Nl"}
TABLES = {
    "other_alphabetic": "otherAlphabetic",
    "ideographic": "ideographic",
    "hiragana": "hiraganaScript",
    "katakana": "katakanaScript",
    "thai": "thaiScript",
    "javanese": "javaneseScript",
    "decimal_digit": "decimalDigit",
}


def letter_ranges(path: Path) -> list[tuple[int, int]]:
    points: list[tuple[int, int]] = []
    pending: tuple[int, str] | None = None
    for line in path.read_text().splitlines():
        fields = line.split(";")
        codepoint, name, category = int(fields[0], 16), fields[1], fields[2]
        if name.endswith(", First>"):
            pending = (codepoint, category)
        elif name.endswith(", Last>"):
            if pending is None or pending[1] != category:
                raise ValueError(f"unmatched Unicode range at U+{codepoint:04X}")
            if category in LETTER_CATEGORIES and pending[0] <= 0xFFFF:
                points.append((pending[0], min(codepoint, 0xFFFF)))
            pending = None
        elif category in LETTER_CATEGORIES and codepoint <= 0xFFFF:
            points.append((codepoint, codepoint))

    merged: list[tuple[int, int]] = []
    for start, end in points:
        if merged and start == merged[-1][1] + 1:
            merged[-1] = (merged[-1][0], end)
        else:
            merged.append((start, end))
    return merged


def kotlin_ranges(path: Path, stem: str) -> list[tuple[int, int]]:
    text = path.read_text()

    def values(suffix: str) -> list[int]:
        match = re.search(
            rf"private val {stem}Range{suffix} = intArrayOf\((.*?)\n\)",
            text,
            re.DOTALL,
        )
        if match is None:
            raise ValueError(f"missing {stem}Range{suffix}")
        return [int(value, 16) for value in re.findall(r"0x[0-9a-fA-F]+", match.group(1))]

    starts, ends = values("Starts"), values("Ends")
    if len(starts) != len(ends):
        raise ValueError(f"mismatched {stem} ranges")
    return list(zip(starts, ends))


def render_table(name: str, ranges: list[tuple[int, int]]) -> str:
    lines = [f"local {name} = {{"]
    row: list[str] = []
    for start, end in ranges:
        row.extend((f"0x{start:x}", f"0x{end:x}"))
        if len(row) == 12:
            lines.append("\t" + ", ".join(row) + ",")
            row = []
    if row:
        lines.append("\t" + ", ".join(row) + ",")
    lines.append("}")
    return "\n".join(lines)


def write_lua(path: Path, letters: list[tuple[int, int]], tables: dict[str, list[tuple[int, int]]]) -> None:
    chunks = [
        "-- Unicode letter categories from UnicodeData.txt 16.0.0 (Unicode License v3).",
        "-- Other properties ported from IntelliJ CharacterUtils.kt (Apache-2.0, © JetBrains s.r.o.).",
        "-- Modified: generated as compact Lua ranges with byte-oriented consumers; see NOTICE.",
        "",
        "local M = {}",
        "",
        render_table("letter", letters),
    ]
    for name, ranges in tables.items():
        chunks.extend(("", render_table(name, ranges)))
    chunks.extend(
        (
            "",
            "---@param codepoint integer",
            "---@param ranges integer[]",
            "---@return boolean",
            "local function in_ranges(codepoint, ranges)",
            "\tlocal low, high = 1, #ranges / 2",
            "\twhile low <= high do",
            "\t\tlocal middle = math.floor((low + high) / 2)",
            "\t\tlocal index = middle * 2 - 1",
            "\t\tif codepoint < ranges[index] then",
            "\t\t\thigh = middle - 1",
            "\t\telseif codepoint > ranges[index + 1] then",
            "\t\t\tlow = middle + 1",
            "\t\telse",
            "\t\t\treturn true",
            "\t\tend",
            "\tend",
            "\treturn false",
            "end",
            "",
            "---@param codepoint integer",
            "---@return boolean",
            "function M.is_alphabetic(codepoint)",
            "\treturn in_ranges(codepoint, letter) or in_ranges(codepoint, other_alphabetic)",
            "end",
        )
    )
    for name in ("ideographic", "hiragana", "katakana", "thai", "javanese", "decimal_digit"):
        chunks.extend(
            (
                "",
                "---@param codepoint integer",
                "---@return boolean",
                f"function M.is_{name}(codepoint)",
                f"\treturn in_ranges(codepoint, {name})",
                "end",
            )
        )
    chunks.extend(("", "return M", ""))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(chunks))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--unicode-data", type=Path, required=True)
    parser.add_argument("--character-utils", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    letters = letter_ranges(args.unicode_data)
    tables = {
        name: kotlin_ranges(args.character_utils, stem)
        for name, stem in TABLES.items()
    }
    write_lua(args.output, letters, tables)
    print(f"letter_ranges={len(letters)}")


if __name__ == "__main__":
    main()
