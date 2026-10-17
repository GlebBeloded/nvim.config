-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/fuzzy-matching/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"",
		"console.log(1)",
		"console.log(2)",
		"console.log(3)",
		"console.log(4)",
		"console.log(5)",
		"console.log(6)",
		"console.log(7)",
		"",
	},
	lines2 = {
		"console.log(1);",
		"console.log(2);",
		"console.log(3);",
		"console.log(4);",
		"",
		"console.log(5);",
		"console.log(6);",
		"console.log(7);",
		"",
		"",
	},
	trim_ws = false,
	changes = {
		{ 0, 8, 0, 9 },
	},
	moves = {},
}
