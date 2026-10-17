-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/just-whitespace/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"console.log('foo'); ",
	},
	lines2 = {
		"console.log('foo');",
	},
	trim_ws = false,
	changes = {
		{ 0, 1, 0, 1 },
	},
	moves = {},
}
