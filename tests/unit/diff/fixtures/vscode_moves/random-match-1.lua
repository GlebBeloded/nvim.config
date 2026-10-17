-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/random-match-1/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"const sourceActions = notebookKernelService.getSourceActions(notebook, editor.scopedContextKeyService);",
		"",
	},
	lines2 = {
		"const sourceActions = notebookKernelService.getSourceActions(notebookTextModel, scopedContextKeyService);",
		"",
	},
	trim_ws = false,
	changes = {
		{ 0, 1, 0, 1 },
	},
	moves = {},
}
