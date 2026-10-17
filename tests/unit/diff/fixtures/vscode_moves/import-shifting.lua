-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/import-shifting/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"import { RuntimeMode } from './runtimeMode';",
		"import { PromiseQueue } from './telemetry';",
		"import { TestNotificationSender, TestUrlOpener } from './testHelpers';",
		"",
	},
	lines2 = {
		"import { RuntimeMode } from './runtimeMode';",
		"import { PromiseQueue, TestPromiseQueue } from './telemetry';",
		"import { TestNotificationSender, TestUrlOpener } from './testHelpers';",
		"",
	},
	trim_ws = false,
	changes = {
		{ 1, 2, 1, 2 },
	},
	moves = {},
}
