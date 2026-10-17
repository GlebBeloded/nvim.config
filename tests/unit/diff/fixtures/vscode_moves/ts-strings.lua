-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/ts-strings/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"interface Test {",
		"    /**",
		"     * Controls whether the fold actions in the gutter stay always visible or hide unless the mouse is over the gutter.",
		"     * Defaults to 'mouseover'.",
		"     */",
		"    showFoldingControls?: 'always' | 'mouseover';",
		"}",
		"",
	},
	lines2 = {
		"interface Test {",
		"    /**",
		"     * Controls whether the fold actions in the gutter stay always visible or hide unless the mouse is over the gutter.",
		"     * Defaults to 'mouseover'.",
		"     */",
		"    showFoldingControls?: 'always' | 'never' | 'mouseover';",
		"}",
		"",
	},
	trim_ws = false,
	changes = {
		{ 5, 6, 5, 6 },
	},
	moves = {},
}
