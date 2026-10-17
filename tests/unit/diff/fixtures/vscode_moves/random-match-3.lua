-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/random-match-3/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"const { selected, all, suggestions, hidden } = notebookKernelService.getMatchingKernel(notebook);",
		"",
	},
	lines2 = {
		"const scopedContextKeyService = editor.scopedContextKeyService;",
		"const matchResult = notebookKernelService.getMatchingKernel(notebook);",
		"const { selected, all } = matchResult;",
		"",
	},
	trim_ws = false,
	changes = {
		{ 0, 1, 0, 3 },
	},
	moves = {},
}
