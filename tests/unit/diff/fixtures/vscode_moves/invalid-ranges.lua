-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/invalid-ranges/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"",
	},
	lines2 = {
		"Tempor duis sunt laborum aliqua id eu irure.",
		"Consequat aliquip excepteur.",
		"Adipisicing incididunt do magn.",
		"",
	},
	trim_ws = false,
	changes = {
		{ 0, 1, 0, 4 },
	},
	moves = {},
}
