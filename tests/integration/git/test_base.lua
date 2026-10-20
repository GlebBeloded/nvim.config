local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, function()
	child.start_config()
end)

T["git: Branch base passes the remote host to gh"] = function()
	local root = F.copy("prbranch", vim.fn.tempname() .. "/prbranch")
	local log = vim.fn.tempname()
	child.lua([[vim.env.FAKE_GH_LOG = ...]], { log })
	child.lua(
		[[BaseResult = false
		require("gleb.git.base").resolve(..., function(info) BaseResult = info end)]],
		{ root }
	)
	eq(child.wait("BaseResult ~= false"), true)
	eq(vim.fn.readfile(log), {
		"pgw.dev\tpr view --json number,url,state,baseRefName,baseRefOid,headRefName,headRefOid",
	})
end

return T
