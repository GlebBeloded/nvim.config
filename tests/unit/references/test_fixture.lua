local MiniTest = require("mini.test")
local F = require("tests.fixtures")

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

local function run_go(root, args)
	local result = vim.system(args, { cwd = root, env = F.go_env(), text = true }):wait(300000)
	eq(result.code, 0)
	eq(result.stderr, "")
end

T["references: gopls kinds classify a Go variable"] = function()
	local root, manifest = F.copy("gomod", vim.fn.tempname())

	eq(vim.fn.readfile(root .. "/report/calls.go"), {
		"package report",
		"",
		"// Calls counts rendered summaries.",
		"var Calls int",
		"",
		"// Count records one rendered summary.",
		"func Count() {",
		"\tCalls++",
		"}",
	})
	eq(vim.fn.readfile(root .. "/report/calls_test.go"), {
		"package report",
		"",
		'import "testing"',
		"",
		"func TestCount(t *testing.T) {",
		"\tCalls = 0",
		"\tCount()",
		"\tif Calls != 1 {",
		'\t\tt.Fatalf("Calls = %d, want 1", Calls)',
		"\t}",
		"}",
	})
	eq(manifest.references.Calls, {
		{ path = "report/calls.go", line = 4, col = 5 },
		{ path = "report/calls.go", line = 8, col = 2 },
		{ path = "report/calls_test.go", line = 6, col = 2 },
		{ path = "report/calls_test.go", line = 8, col = 5 },
		{ path = "report/calls_test.go", line = 9, col = 35 },
	})
	eq(manifest.references.Format, {
		{ path = "internal/money/money.go", line = 6, col = 6 },
		{ path = "internal/money/money_test.go", line = 6, col = 12 },
		{ path = "billing/invoice.go", line = 16, col = 15 },
		{ path = "billing/invoice.go", line = 23, col = 31 },
		{ path = "report/summary.go", line = 7, col = 27 },
	})
	run_go(root, { "go", "build", "./..." })
	run_go(root, { "go", "vet", "./..." })
end

return T
