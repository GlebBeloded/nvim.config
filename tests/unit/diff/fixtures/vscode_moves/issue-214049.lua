-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/issue-214049/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"hello world; ",
		"y",
	},
	lines2 = {
		"hello world;",
		"// new line",
		"y",
	},
	trim_ws = false,
	changes = {
		{ 0, 1, 0, 2 },
	},
	moves = {},
}
