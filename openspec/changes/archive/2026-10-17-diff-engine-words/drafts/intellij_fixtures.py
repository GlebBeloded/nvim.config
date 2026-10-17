#!/usr/bin/env python3
"""Translate pinned IntelliJ inner-comparison tests into Lua fixtures."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator


PIN = "d422387398cbecf45702238cfee4acc71bd2b97d"
TEST_PATH = Path("platform/diff-impl/tests/testSrc/com/intellij/diff/comparison")
POLICIES = ("default", "trim_whitespaces", "ignore_whitespaces")
POLICY_NAMES = {
    "default": "default",
    "trim": "trim_whitespaces",
    "ignore": "ignore_whitespaces",
}
CONSTANTS = {
    "chSmile": "😂",
    "chGun": "🔫",
    "chMan": "🧒",
    "chFace": "🤫",
}
STRING = re.compile(r'"(?:\\.|[^"\\])*"')
PAIR = re.compile(f"({STRING.pattern})\\s*-\\s*({STRING.pattern})", re.DOTALL)


@dataclass
class Block:
    kind: str
    options: str
    text: str
    line: int


def kotlin_string(token: str) -> str:
    return json.loads(token)


def lua_string(value: str) -> str:
    rendered = json.dumps(value, ensure_ascii=False)
    return re.sub(r"\\u00([0-9a-fA-F]{2})", r"\\x\1", rendered)


def expand_constants(text: str) -> str:
    for name, value in CONSTANTS.items():
        text = text.replace(f"${name}", value)
        text = re.sub(rf"\b{name}\b", lua_string(value), text)
    return text


def strip_comments(text: str) -> str:
    output: list[str] = []
    index = 0
    in_string = False
    while index < len(text):
        char = text[index]
        if char == '"' and (index == 0 or text[index - 1] != "\\"):
            in_string = not in_string
        if not in_string and text.startswith("//", index):
            end = text.find("\n", index)
            if end == -1:
                break
            output.append("\n")
            index = end + 1
            continue
        output.append(char)
        index += 1
    return "".join(output)


def named_blocks(text: str, names: tuple[str, ...]) -> Iterator[Block]:
    pattern = re.compile(rf"\b({'|'.join(names)})\s*(?:\(([^{{}}]*)\))?\s*\{{")
    for match in pattern.finditer(text):
        start = match.end()
        depth = 1
        index = start
        in_string = False
        while depth and index < len(text):
            char = text[index]
            if char == '"' and (index == 0 or text[index - 1] != "\\"):
                in_string = not in_string
            elif not in_string and text.startswith("//", index):
                newline = text.find("\n", index)
                index = len(text) if newline == -1 else newline
                continue
            elif not in_string and char == "{":
                depth += 1
            elif not in_string and char == "}":
                depth -= 1
            index += 1
        if depth:
            raise ValueError(f"unterminated {match.group(1)} block")
        yield Block(
            match.group(1),
            match.group(2) or "",
            text[start : index - 1],
            text.count("\n", 0, match.start()) + 1,
        )


def calls(text: str, name: str) -> Iterator[str]:
    pattern = re.compile(rf"(?<![.\w]){name}\s*\(")
    for match in pattern.finditer(text):
        start = match.end()
        depth = 1
        index = start
        in_string = False
        while depth and index < len(text):
            char = text[index]
            if char == '"' and (index == 0 or text[index - 1] != "\\"):
                in_string = not in_string
            elif not in_string and char == "(":
                depth += 1
            elif not in_string and char == ")":
                depth -= 1
            index += 1
        if depth:
            raise ValueError(f"unterminated {name} call")
        yield text[start : index - 1]


def utf16_to_byte(text: str, offset: int) -> int:
    units = 0
    byte_offset = 0
    for char in text:
        if units == offset:
            return byte_offset
        width = 2 if ord(char) >= 0x10000 else 1
        if units + width > offset:
            return byte_offset
        units += width
        byte_offset += len(char.encode())
    if units != offset:
        raise ValueError(f"UTF-16 offset {offset} is outside {text!r}")
    return byte_offset


def changed_bytes(mask: str, text: str) -> list[int]:
    pattern = mask.replace(".", "")
    unit_bytes: list[list[int]] = []
    byte_offset = 0
    for char in text:
        indexes = list(range(byte_offset, byte_offset + len(char.encode())))
        unit_bytes.extend([indexes] * (2 if ord(char) >= 0x10000 else 1))
        byte_offset += len(char.encode())
    if len(pattern) != len(unit_bytes):
        raise ValueError(f"matching length {len(pattern)} != UTF-16 length {len(unit_bytes)} for {text!r}")
    changed: set[int] = set()
    for index, marker in enumerate(pattern):
        if marker != " ":
            changed.update(unit_bytes[index])
    return sorted(changed)


def fragments(arguments: str, text1: str, text2: str, byte_offsets: bool) -> list[list[int]]:
    result: list[list[int]] = []
    for kind, raw in re.findall(r"\b(mod|del|ins)\(([^()]*)\)", arguments):
        values = [int(value.strip()) for value in raw.split(",")]
        if kind == "mod":
            start1, start2, count1, count2 = values
        elif kind == "del":
            start1, start2, count1 = values
            count2 = 0
        else:
            start1, start2, count2 = values
            count1 = 0
        end1 = start1 + count1
        end2 = start2 + count2
        if byte_offsets:
            start1, end1 = utf16_to_byte(text1, start1), utf16_to_byte(text1, end1)
            start2, end2 = utf16_to_byte(text2, start2), utf16_to_byte(text2, end2)
        result.append([start1, end1, start2, end2])
    return result


def resolve(values: dict[str, object], policy: str) -> object | None:
    if policy == "default":
        return values.get("default")
    if policy == "trim_whitespaces":
        return values.get("trim_whitespaces", values.get("default"))
    return values.get("ignore_whitespaces", values.get("trim_whitespaces", values.get("default")))


def run_policies(body: str) -> tuple[str, ...]:
    if "testAll" in body:
        return POLICIES
    if "testDefault" in body:
        return ("default",)
    if "testTrim" in body:
        return ("trim_whitespaces",)
    if "testIgnore" in body:
        return ("ignore_whitespaces",)
    raise ValueError("block has no test invocation")


def parse_comparison_rows(path: Path, names: tuple[str, ...]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    text = expand_constants(path.read_text())
    for block in named_blocks(text, names):
        body = strip_comments(block.text)
        pairs = list(PAIR.finditer(body))
        if not pairs:
            raise ValueError(f"missing source at {path.name}:{block.line}")
        text1, text2 = (kotlin_string(token) for token in pairs[0].groups())
        if ".plainSource()" not in body[pairs[0].end() : pairs[0].end() + 32]:
            text1, text2 = text1.replace("_", "\n"), text2.replace("_", "\n")

        ranges: dict[str, object] = {}
        matchings: dict[str, object] = {}
        for kotlin_name, policy in POLICY_NAMES.items():
            policy_calls = list(calls(body, kotlin_name))
            if policy_calls:
                ranges[policy] = fragments(
                    policy_calls[-1], text1, text2, block.kind != "splitter"
                )
        for pair in pairs[1:]:
            suffix = body[pair.end() :]
            policy_match = re.match(r"\s*\)\s*\.\s*(default|trim|ignore)\s*\(\s*\)", suffix)
            if policy_match:
                mask1, mask2 = (kotlin_string(token) for token in pair.groups())
                matchings[POLICY_NAMES[policy_match.group(1)]] = {
                    "changed1": changed_bytes(mask1, text1),
                    "changed2": changed_bytes(mask2, text2),
                }

        expected: dict[str, object] = {}
        for policy in run_policies(body):
            policy_expected: dict[str, object] = {}
            selected_ranges = resolve(ranges, policy)
            selected_matching = resolve(matchings, policy)
            if selected_ranges is not None:
                policy_expected["fragments"] = selected_ranges
            if selected_matching is not None:
                policy_expected.update(selected_matching)  # type: ignore[arg-type]
            if not policy_expected:
                raise ValueError(f"no expectation for {policy} at {path.name}:{block.line}")
            expected[policy] = policy_expected

        row: dict[str, object] = {
            "source": f"{path.name}:{block.line}",
            "kind": block.kind,
            "text1": text1,
            "text2": text2,
            "expect": expected,
        }
        if block.kind == "splitter":
            row["squash"] = bool(re.search(r"\bsquash\s*=\s*true", block.options))
            row["trim"] = bool(re.search(r"\btrim\s*=\s*true", block.options))
        rows.append(row)
    return rows


def parse_class_rows(path: Path) -> dict[str, object]:
    text = expand_constants(path.read_text())

    def verdicts(name: str) -> list[dict[str, object]]:
        pattern = re.compile(rf"{name}\s*\(\s*({STRING.pattern})\s*,\s*(true|false)\s*\)")
        return [
            {"text": kotlin_string(match.group(1)), "expected": match.group(2) == "true"}
            for match in pattern.finditer(text)
        ]

    punctuation = re.search(rf"PUNCTUATION\s*=\s*({STRING.pattern})", text)
    if punctuation is None:
        raise ValueError("missing punctuation table")
    return {
        "punctuation": kotlin_string(punctuation.group(1)),
        "alpha": verdicts("assertIsAlpha"),
        "continuous": verdicts("assertIsContinuous"),
    }


def lua_value(value: object) -> str:
    if isinstance(value, str):
        return lua_string(value)
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, list):
        return "{ " + ", ".join(lua_value(item) for item in value) + " }"
    if isinstance(value, dict):
        fields = []
        for key, item in value.items():
            rendered = key if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key) else f"[{lua_string(key)}]"
            fields.append(f"{rendered} = {lua_value(item)}")
        return "{ " + ", ".join(fields) + " }"
    raise TypeError(type(value))


def write_fixture(path: Path, upstream: str, value: object) -> None:
    header = (
        f"-- Translated from intellij-community (Apache-2.0, © JetBrains s.r.o.) at {PIN[:8]}:\n"
        f"-- {TEST_PATH / upstream}\n"
        "-- Modified: Kotlin DSL rewritten as Lua data and UTF-16 offsets as UTF-8 bytes; see lua/gleb/diff/engine/NOTICE.\n"
    )
    if isinstance(value, list):
        content = header + "return {\n" + "".join(f"\t{lua_value(row)},\n" for row in value) + "}\n"
    else:
        content = header + "return " + lua_value(value) + "\n"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--intellij", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = args.intellij / TEST_PATH

    words = parse_comparison_rows(source / "WordComparisonUtilTest.kt", ("lines_inner", "words"))
    chars = parse_comparison_rows(source / "CharComparisonUtilTest.kt", ("chars", "chars_raw", "chars_smart"))
    split = parse_comparison_rows(source / "SplitComparisonUtilTest.kt", ("splitter",))
    split += parse_comparison_rows(source / "LineComparisonUtilTest.kt", ("splitter",))
    classes = parse_class_rows(source / "TrimUtilTest.kt")
    if (len(words), len(chars), len(split)) != (78, 71, 27):
        raise ValueError(f"unexpected fixture counts: {len(words)}, {len(chars)}, {len(split)}")

    write_fixture(args.output / "intellij_words.lua", "WordComparisonUtilTest.kt", words)
    write_fixture(args.output / "intellij_chars.lua", "CharComparisonUtilTest.kt", chars)
    write_fixture(
        args.output / "intellij_split.lua",
        "SplitComparisonUtilTest.kt and LineComparisonUtilTest.kt",
        split,
    )
    write_fixture(args.output / "intellij_chars_classes.lua", "TrimUtilTest.kt", classes)
    print(f"words={len(words)} chars={len(chars)} split={len(split)}")


if __name__ == "__main__":
    main()
