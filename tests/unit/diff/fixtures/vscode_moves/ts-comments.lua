-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/ts-comments/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"interface Test {",
		"    /**",
		"     * Render +/- indicators for added/deleted changes.",
		"     * Defaults to true.",
		"     */",
		"    renderIndicators?: boolean;",
		"    /**",
		"     * Original model should be editable?",
		"     * Defaults to false.",
		"     */",
		"    originalEditable?: boolean;",
		"}",
	},
	lines2 = {
		"interface Test {",
		"    /**",
		"     * Render +/- indicators for added/deleted changes.",
		"     * Defaults to true.",
		"     */",
		"    renderIndicators?: boolean;",
		"    /**",
		"     * Shows icons in the glyph margin to revert changes.",
		"     * Default to true.",
		"     */",
		"    renderMarginRevertIcon?: boolean;",
		"    /**",
		"     * Original model should be editable?",
		"     * Defaults to false.",
		"     */",
		"    originalEditable?: boolean;",
		"}",
	},
	trim_ws = false,
	changes = {
		{ 6, 6, 6, 11 },
	},
	moves = {},
}
