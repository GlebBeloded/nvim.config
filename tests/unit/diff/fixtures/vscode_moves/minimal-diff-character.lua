-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/minimal-diff-character/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"import * as path from 'path';",
		"import { Command } from 'vscode';",
		"import * as nls from 'vscode-nls';",
		"",
		'"()()()()()()()()()()()()()"',
	},
	lines2 = {
		"import * as path from 'path';",
		"import { Command, commands } from 'vscode';",
		"import * as nls from 'vscode-nls';",
		"",
		'"Gallicum()est()divisa()in()partres()tres()quarum()unam()est()()()()()()()()()()()()"',
	},
	trim_ws = false,
	changes = {
		{ 1, 2, 1, 2 },
		{ 4, 5, 4, 5 },
	},
	moves = {},
}
