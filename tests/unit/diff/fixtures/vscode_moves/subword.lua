-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/subword/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"import { EditorSimpleWorker } from 'vs/editor/common/services/editorSimpleWorker';",
		"import { IEditorWorkerService, IUnicodeHighlightsResult } from 'vs/editor/common/services/editorWorker';",
		"import { IModelService } from 'vs/editor/common/services/model';",
		"",
		"let x: [IEditorWorkerService, EditorSimpleWorker, IModelService, IUnicodeHighlightsResult];",
	},
	lines2 = {
		"import { EditorSimpleWorker } from 'vs/editor/common/services/editorSimpleWorker';",
		"import { IDiffComputationResult, IEditorWorkerService, IUnicodeHighlightsResult } from 'vs/editor/common/services/editorWorker';",
		"import { IModelService } from 'vs/editor/common/services/model';",
		"",
		"let x: [IEditorWorkerService, EditorSimpleWorker, IModelService, IUnicodeHighlightsResult];",
		"let y: IDiffComputationResult;",
	},
	trim_ws = false,
	changes = {
		{ 1, 2, 1, 2 },
		{ 5, 5, 5, 6 },
	},
	moves = {},
}
