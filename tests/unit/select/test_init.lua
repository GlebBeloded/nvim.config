local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		select_calls = 0
		vim.ui.select = function(items, opts, on_choice)
			select_calls = select_calls + 1
			on_choice(items[1], 1)
		end
		package.loaded["gleb.select.code_action"] = {}
		require("gleb.select")
	]])
end

local T = H.child_set(child, start)

T["select: Selection accepts omitted options"] = function()
	local result = child.lua_get([[
		(function()
			local choice
			vim.ui.select({ "x" }, nil, function(item, index) choice = { item, index } end)
			return { calls = select_calls, choice = choice }
		end)()
	]])

	eq(result, { calls = 1, choice = { "x", 1 } })
end

return T
