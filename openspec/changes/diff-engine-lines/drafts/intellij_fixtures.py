#!/usr/bin/env python3
"""Translate pinned IntelliJ line-comparison tests into Lua fixtures."""

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
STRING = re.compile(r'"(?:\\.|[^"\\])*"')
PAIR = re.compile(f"({STRING.pattern})\\s*-\\s*({STRING.pattern})", re.DOTALL)


@dataclass
class Block:
    text: str
    line: int


def kotlin_string(token: str) -> str:
    return json.loads(token)


def lua_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


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


def line_blocks(text: str) -> Iterator[Block]:
    for match in re.finditer(r"\blines\s*\{", text):
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
            raise ValueError(f"unterminated lines block at offset {match.start()}")
        yield Block(text[start : index - 1], text.count("\n", 0, match.start()) + 1)


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


def fragments(arguments: str) -> list[list[int]]:
    result: list[list[int]] = []
    for kind, raw in re.findall(r"\b(mod|del|ins)\(([^()]*)\)", arguments):
        values = [int(value.strip()) for value in raw.split(",")]
        if kind == "mod":
            line1, line2, count1, count2 = values
        elif kind == "del":
            line1, line2, count1 = values
            count2 = 0
        else:
            line1, line2, count2 = values
            count1 = 0
        result.append([line1, line1 + count1, line2, line2 + count2])
    return result


def changed_lines(mask: str) -> list[int]:
    changed: list[int] = []
    index = 0
    line = 0
    while index < len(mask):
        positions = [position for position in (mask.find("_", index), mask.find("*", index)) if position >= 0]
        end = min(positions) + 1 if positions else len(mask)
        segment = mask[index:end]
        if any(char not in " _" for char in segment):
            changed.append(line)
        line += 1
        index = end
    return changed


def resolve(values: dict[str, object], policy: str) -> object | None:
    if policy == "default":
        return values.get("default")
    if policy == "trim_whitespaces":
        return values.get("trim_whitespaces", values.get("default"))
    return values.get("ignore_whitespaces", values.get("trim_whitespaces", values.get("default")))


def parse_line_rows(path: Path) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for block in line_blocks(path.read_text()):
        body = strip_comments(block.text)
        pairs = list(PAIR.finditer(body))
        if not pairs:
            raise ValueError(f"no source pair at {path.name}:{block.line}")
        source1, source2 = (kotlin_string(token) for token in pairs[0].groups())
        source1 = source1.replace("_", "\n")
        source2 = source2.replace("_", "\n")

        range_values: dict[str, object] = {}
        matching_values: dict[str, object] = {}
        for kotlin_name, policy in POLICY_NAMES.items():
            policy_calls = list(calls(body, kotlin_name))
            if policy_calls:
                range_values[policy] = fragments(policy_calls[-1])
        for pair in pairs[1:]:
            suffix = body[pair.end() :]
            policy_match = re.match(r"\s*\)\s*\.\s*(default|trim|ignore)\s*\(\s*\)", suffix)
            if policy_match:
                mask1, mask2 = (kotlin_string(token) for token in pair.groups())
                matching_values[POLICY_NAMES[policy_match.group(1)]] = {
                    "changed1": changed_lines(mask1),
                    "changed2": changed_lines(mask2),
                }

        if "testAll" in body:
            run_policies = POLICIES
        elif "testDefault" in body:
            run_policies = ("default",)
        elif "testTrim" in body:
            run_policies = ("trim_whitespaces",)
        elif "testIgnore" in body:
            run_policies = ("ignore_whitespaces",)
        else:
            raise ValueError(f"no test invocation at {path.name}:{block.line}")

        expected: dict[str, object] = {}
        for policy in run_policies:
            policy_expected: dict[str, object] = {}
            ranges = resolve(range_values, policy)
            matching = resolve(matching_values, policy)
            if ranges is not None:
                policy_expected["fragments"] = ranges
            if matching is not None:
                policy_expected.update(matching)  # type: ignore[arg-type]
            if not policy_expected:
                raise ValueError(f"no expectation for {policy} at {path.name}:{block.line}")
            expected[policy] = policy_expected

        rows.append(
            {
                "source": f"{path.name}:{block.line}",
                "lines1": source1.split("\n"),
                "lines2": source2.split("\n"),
                "expect": expected,
            }
        )
    return rows


def parse_equality_rows(path: Path) -> list[dict[str, object]]:
    text = path.read_text()
    rows: list[dict[str, object]] = []
    for match in re.finditer(rf"doTestTrim\((true|false),\s*({STRING.pattern}),\s*({STRING.pattern})\)", text):
        rows.append(
            {
                "source": f"{path.name}:{text.count(chr(10), 0, match.start()) + 1}",
                "kind": "trim_equality",
                "equal": match.group(1) == "true",
                "lines1": kotlin_string(match.group(2)).split("\n"),
                "lines2": kotlin_string(match.group(3)).split("\n"),
            }
        )

    line_fragment = re.compile(
        rf"doTestLineFragment\(\s*({STRING.pattern}),\s*({STRING.pattern}),"
        r"\s*!\d+\s*-\s*\d+,\s*!\d+\s*-\s*\d+,"
        r"\s*!(\d+)\s*-\s*(\d+),\s*!(\d+)\s*-\s*(\d+)\s*\)",
        re.DOTALL,
    )
    for match in line_fragment.finditer(text):
        rows.append(
            {
                "source": f"{path.name}:{text.count(chr(10), 0, match.start()) + 1}",
                "kind": "line_fragment",
                "lines1": kotlin_string(match.group(1)).replace("_", "\n").split("\n"),
                "lines2": kotlin_string(match.group(2)).replace("_", "\n").split("\n"),
                "fragments": [[int(value) for value in match.groups()[2:]]],
            }
        )
    return rows


def lua_value(value: object, indent: int = 0) -> str:
    if isinstance(value, str):
        return lua_string(value)
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, list):
        return "{ " + ", ".join(lua_value(item, indent + 1) for item in value) + " }"
    if isinstance(value, dict):
        fields = []
        for key, item in value.items():
            rendered_key = key if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key) else f"[{lua_string(key)}]"
            fields.append(f"{rendered_key} = {lua_value(item, indent + 1)}")
        return "{ " + ", ".join(fields) + " }"
    raise TypeError(type(value))


def write_fixture(path: Path, upstream: str, rows: list[dict[str, object]]) -> None:
    header = (
        f"-- Translated from intellij-community (Apache-2.0, © JetBrains s.r.o.) at {PIN[:8]}:\n"
        f"-- {TEST_PATH / upstream}\n"
        "-- Modified: Kotlin DSL rewritten as Lua data.\n"
    )
    content = header + "return {\n" + "".join(f"\t{lua_value(row)},\n" for row in rows) + "}\n"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--intellij", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    source_dir = args.intellij / TEST_PATH
    line_rows = parse_line_rows(source_dir / "LineComparisonUtilTest.kt")
    equality_rows = parse_equality_rows(source_dir / "ComparisonUtilTest.kt")
    if (len(line_rows), len(equality_rows)) != (69, 45):
        raise ValueError(f"unexpected fixture counts: {len(line_rows)}, {len(equality_rows)}")

    write_fixture(args.output / "intellij_lines.lua", "LineComparisonUtilTest.kt", line_rows)
    write_fixture(args.output / "intellij_equality.lua", "ComparisonUtilTest.kt", equality_rows)
    print(f"LineComparisonUtilTest.kt: {len(line_rows)}")
    print(f"ComparisonUtilTest.kt: {len(equality_rows)}")


if __name__ == "__main__":
    main()
