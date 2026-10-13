local MiniTest = require("mini.test")
local H = require("tests.helpers")
local cases = require("tests.render.cases")

local eq = MiniTest.expect.equality
local child = H.new_child()

local ASYNC_MS = 5000

local function start()
	child.start_config()
	child.wait_very_lazy()
	cases["git-hunk"].setup(child)
end

--- Lua run in the child: sign text of the gitsigns extmark on line 2.
local LINE2_SIGN_LUA = [[(function()
	for name, ns in pairs(vim.api.nvim_get_namespaces()) do
		if name:find("^gitsigns_signs_") then
			local mark = vim.api.nvim_buf_get_extmarks(0, ns, { 1, 0 }, { 1, -1 }, { details = true })[1]
			if mark then
				return mark[4].sign_text
			end
		end
	end
end)()]]

local T = H.child_set(child, start)

T["git: Added line shows bar sign"] = function()
	eq(child.wait(LINE2_SIGN_LUA .. " ~= nil", ASYNC_MS), true)
	eq(vim.trim(child.lua_get(LINE2_SIGN_LUA)), "┃")
end

return T
