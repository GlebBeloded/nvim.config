-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/issue-202147-trimws/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"",
		"",
		"\t\titem.row!.domNode.classList.toggle('drop-target', item.dropTarget);",
		"\t}",
		"",
		"",
		"a",
		"x",
		"a",
		"a",
		"a",
	},
	lines2 = {
		"",
		"",
		"\t\titem.row!.domNode.classList.toggle('drop-target', item.dropTarget !== false);",
		"\t\tif (typeof item.dropTarget !== 'boolean') {",
		"\t\t\titem.row!.domNode.classList.toggle('drop-target-start', item.dropTarget.first);",
		"\t\t}",
		"\t}",
		"",
		"",
		"a",
		"x",
		"a",
		"a",
		"",
	},
	trim_ws = true,
	changes = {
		{ 2, 3, 2, 6 },
		{ 10, 11, 13, 14 },
	},
	moves = {},
}
