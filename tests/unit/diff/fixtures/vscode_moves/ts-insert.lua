-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/ts-insert/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"const sequence2 = new SequenceFromIntArray(tgtDocLines);",
	},
	lines2 = {
		"const sequence2 = new LineSequence(tgtDocLines, modifiedLines);",
	},
	trim_ws = false,
	changes = {
		{ 0, 1, 0, 1 },
	},
	moves = {},
}
