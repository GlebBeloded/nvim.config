local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

T["loop: Loop clean skips a branch that is already gone"] = function()
	local result = H.system(
		child,
		{ "python3", "-m", "unittest", "-q", "test_loop_clean" },
		vim.fs.joinpath(H.root, ".archon/scripts")
	)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
end

return T
