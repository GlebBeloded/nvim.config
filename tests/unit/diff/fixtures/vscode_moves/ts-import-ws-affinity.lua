-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/ts-import-ws-affinity/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"import { handledConflictMinimapOverViewRulerColor, unhandledConflictMinimapOverViewRulerColor } from 'vs/workbench/contrib/mergeEditor/browser/view/colors';",
		"import { EditorGutter, IGutterItemInfo, IGutterItemView } from '../editorGutter';",
		"import { CodeEditorView } from './codeEditorView';",
		"",
	},
	lines2 = {
		"import { handledConflictMinimapOverViewRulerColor, unhandledConflictMinimapOverViewRulerColor } from 'vs/workbench/contrib/mergeEditor/browser/view/colors';",
		"import { EditorGutter, IGutterItemInfo, IGutterItemView } from '../editorGutter';",
		"import { CodeEditorView, TitleMenu } from './codeEditorView';",
		"",
	},
	trim_ws = false,
	changes = {
		{ 2, 3, 2, 3 },
	},
	moves = {},
}
