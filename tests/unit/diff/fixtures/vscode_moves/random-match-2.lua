-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/random-match-2/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"if (!all.length && !sourceActions.length) {",
		"\tconst activeNotebookModel = getNotebookEditorFromEditorPane(editorService.activeEditorPane)?.textModel;",
		"\tif (activeNotebookModel) {",
		"\t\tconst language = this.getSuggestedLanguage(activeNotebookModel);",
		"\t\tsuggestedExtension = language ? this.getSuggestedKernelFromLanguage(activeNotebookModel.viewType, language) : undefined;",
		"\t}",
		"\tif (suggestedExtension) {",
		"",
	},
	lines2 = {
		"if (!all.length && !sourceActions.length) {",
		"\tconst language = this.getSuggestedLanguage(notebookTextModel);",
		"\tsuggestedExtension = language ? this.getSuggestedKernelFromLanguage(notebookTextModel.viewType, language) : undefined;",
		"\tif (suggestedExtension) {",
		"",
	},
	trim_ws = false,
	changes = {
		{ 1, 6, 1, 3 },
	},
	moves = {},
}
