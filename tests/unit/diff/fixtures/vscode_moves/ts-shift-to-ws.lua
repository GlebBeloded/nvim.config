-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/ts-shift-to-ws/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"const childEndsAfterEnd = lengthGreaterThanEqual(nodeOffsetEnd, endOffset);",
		"if (childEndsAfterEnd) {",
		"    // No child after this child in the requested window, don't recurse",
		"    node = child;",
		"    level++;",
		"    continue whileLoop;",
		"}",
		"",
		"const shouldContinue = collectBrackets(child, nodeOffsetStart, nodeOffsetEnd, startOffset, endOffset, push, level + 1, levelPerBracketType);",
		"if (!shouldContinue) {",
		"    return false;",
		"}",
	},
	lines2 = {
		"const childEndsAfterEnd = lengthGreaterThanEqual(nodeOffsetEnd, endOffset);",
		"if (childEndsAfterEnd) {",
		"    // No child after this child in the requested window, don't recurse",
		"    node = child;",
		"    level++;",
		"    continue whileLoop;",
		"}",
		"",
		"const shouldContinue = collectBrackets(child, nodeOffsetStart, nodeOffsetEnd, startOffset, endOffset, push, level + 1, levelPerBracket + 1, levelPerBracketType);",
		"if (!shouldContinue) {",
		"    return false;",
		"}",
	},
	trim_ws = false,
	changes = {
		{ 8, 9, 8, 9 },
	},
	moves = {},
}
