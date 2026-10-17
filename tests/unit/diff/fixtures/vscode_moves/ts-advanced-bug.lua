-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/ts-advanced-bug/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"function compileProgram(): ExitStatus {",
		"    // First get any syntactic errors. ",
		"    var diagnostics = program.getSyntacticDiagnostics();",
		"    reportDiagnostics(diagnostics);",
		"",
		"    // If we didn't have any syntactic errors, then also try getting the global and",
		"    // semantic errors.",
		"    if (diagnostics.length === 0) ",
	},
	lines2 = {
		"function compileProgram(): ExitStatus {",
		"    let diagnostics: Diagnostic[];",
		"    ",
		"    // First get and report any syntactic errors.",
		"    diagnostics = program.getSyntacticDiagnostics();",
		"",
		"    // If we didn't have any syntactic errors, then also try getting the global and",
		"    // semantic errors.",
		"    if (diagnostics.length === 0) {",
	},
	trim_ws = false,
	changes = {
		{ 1, 4, 1, 5 },
		{ 7, 8, 8, 9 },
	},
	moves = {},
}
