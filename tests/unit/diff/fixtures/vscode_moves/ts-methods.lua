-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/ts-methods/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"interface Test {",
		"    getDecorationsInViewport(visibleRange: Range): ViewModelDecoration[];",
		"\tgetViewLineRenderingData(visibleRange: Range, lineNumber: number): ViewLineRenderingData;",
		"    getViewLineData(lineNumber: number): ViewLineData;",
		"}",
	},
	lines2 = {
		"interface Test {",
		"    getDecorationsInViewport(visibleRange: Range): ViewModelDecoration[];",
		"    getViewportViewLineRenderingData(visibleRange: Range, lineNumber: number): ViewLineRenderingData;",
		"    getViewLineRenderingData(lineNumber: number): ViewLineRenderingData;",
		"    getViewLineData(lineNumber: number): ViewLineData;",
		"}",
	},
	trim_ws = false,
	changes = {
		{ 2, 3, 2, 4 },
	},
	moves = {},
}
