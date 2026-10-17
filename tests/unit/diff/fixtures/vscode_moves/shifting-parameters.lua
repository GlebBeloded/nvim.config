-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/shifting-parameters/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"function x(alignments: RangeMapping[]): x[] { }",
		"",
	},
	lines2 = {
		"function x(alignments: RangeMapping[], originalLines: string[], modifiedLines: string[]): x[] { }",
		"",
	},
	trim_ws = false,
	changes = {
		{ 0, 1, 0, 1 },
	},
	moves = {},
}
