-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/ts-fragmented-eager-diffing3/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"import { assertIsDefined } from 'vs/base/common/types';",
		"import { IInstantiationService, ServicesAccessor } from 'vs/platform/instantiation/common/instantiation';",
		"import { MenuId, Action2, IAction2Options, IMenuServiceFooManager, ServiceManagerLocator } from 'vs/platform/actions/common/actions';",
		"import { createActionViewItem } from 'vs/platform/actions/browser/menuEntryActionViewItem';",
		"import { parseLinkedText } from 'vs/base/common/linkedText';",
		"import { IOpenerService } from 'vs/platform/opener/common/opener';",
		"ISFM,SML,SFMKL",
		"",
		"console.log(MenuId, Action2, IAction2Options, IMenuServiceFooManager, ServiceManagerLocator);",
	},
	lines2 = {
		"import { assertIsDefined } from 'vs/base/common/types';",
		"import { IInstantiationService, ServicesAccessor } from 'vs/platform/instantiation/common/instantiation';",
		"import { MenuId, Action2, IAction2Options, ServiceManagerLocator } from 'vs/platform/actions/common/actions';",
		"import { createActionViewItem } from 'vs/platform/actions/browser/menuEntryActionViewItem';",
		"import { parseLinkedText } from 'vs/base/common/linkedText';",
		"import { IOpenerService } from 'vs/platform/opener/common/opener';",
		"SML",
		"",
		"console.log(MenuId, Action2, IAction2Options, ServiceManagerLocator);",
	},
	trim_ws = false,
	changes = {
		{ 2, 3, 2, 3 },
		{ 6, 7, 6, 7 },
		{ 8, 9, 8, 9 },
	},
	moves = {},
}
