-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/intra-block-align/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"console.log(1);",
		"console.log(2);",
		"console.log(3);",
		"console.log(4);",
		"",
	},
	lines2 = {
		"console.log(1)",
		"console.log(2)",
		"console.log(4)",
		"",
	},
	trim_ws = false,
	changes = {
		{ 0, 4, 0, 3 },
	},
	moves = {},
}
