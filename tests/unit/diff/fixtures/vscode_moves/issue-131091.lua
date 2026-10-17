-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/issue-131091/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"{",
		"\tif (A) {",
		"\t\tif (B) {",
		"\t\t\tdoit",
		"\t\t}",
		"\t}",
		"}",
		"C",
		"X",
		"",
	},
	lines2 = {
		"{",
		"\tif (A && B) {",
		"\t\tdoit",
		"\t}",
		"}",
		"C",
		"Y",
		"",
	},
	trim_ws = false,
	changes = {
		{ 1, 5, 1, 3 },
		{ 8, 9, 6, 7 },
	},
	moves = {},
}
