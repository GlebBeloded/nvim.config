-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/ts-diff-word-split/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"import { findLast } from 'vs/base/common/arrays';",
		"import { Disposable } from 'vs/base/common/lifecycle';",
		"import { ITransaction, observableValue, transaction } from 'vs/base/common/observable';",
		"import { Range } from 'vs/editor/common/core/range';",
		"import { ScrollType } from 'vs/editor/common/editorCommon';",
		"import { IFooBar, IFoo } from 'foo';",
		"",
		"console.log(observableValue);",
		"",
		"console.log(observableValue);",
		"",
	},
	lines2 = {
		"import { findLast } from 'vs/base/common/arrays';",
		"import { Disposable } from 'vs/base/common/lifecycle';",
		"import { ITransaction, observableFromEvent, observableValue, transaction } from 'vs/base/common/observable';",
		"import { Range } from 'vs/editor/common/core/range';",
		"import { ScrollType } from 'vs/editor/common/editorCommon';",
		"import { IFooBar, IBar, IFoo } from 'foo';",
		"",
		"console.log(observableFromEvent, observableValue);",
		"",
		"console.log(observableValue, observableFromEvent);",
		"",
	},
	trim_ws = false,
	changes = {
		{ 2, 3, 2, 3 },
		{ 5, 6, 5, 6 },
		{ 7, 8, 7, 8 },
		{ 9, 10, 9, 10 },
	},
	moves = {},
}
