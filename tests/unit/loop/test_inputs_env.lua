local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T["loop: Tests never see an Archon node's inputs"] = function()
	local root = H.root
	local script = "io.write(tostring(vim.env.INPUTS_CANCEL_ON_REJECT), ' ', tostring(vim.env.BASE_BRANCH))"
	local result = vim.system({
		vim.v.progpath,
		"--headless",
		"-u",
		vim.fs.joinpath(root, "tests/minimal_init.lua"),
		"-c",
		"lua " .. script,
		"-c",
		"qa!",
	}, {
		env = {
			INPUTS_CANCEL_ON_REJECT = "false",
			BASE_BRANCH = "loop/x",
			TEST_DEPS_DIR = vim.fs.joinpath(root, ".tests/deps"),
		},
		text = true,
	}):wait()
	eq(result.code, 0, { fail_reason = result.stderr })
	eq(result.stdout .. result.stderr, "nil nil")
end

return T
