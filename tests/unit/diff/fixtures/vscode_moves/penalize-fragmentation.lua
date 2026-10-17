-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/penalize-fragmentation/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"import { IChange, IDiffComputationResult } from 'vs/editor/common/diff/diffComputer';",
	},
	lines2 = {
		"import { IDocumentDiffProviderOptions } from 'vs/editor/common/diff/documentDiffProvider';",
		"import { IChange } from 'vs/editor/common/diff/smartLinesDiffComputer';",
	},
	trim_ws = false,
	changes = {
		{ 0, 1, 0, 2 },
	},
	moves = {},
}
