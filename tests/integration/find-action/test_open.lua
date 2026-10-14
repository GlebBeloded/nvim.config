local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_config()
	child.wait_very_lazy()
end

local T = H.child_set(child, start)

local function expect_find_action(editor_win)
	assert(child.wait("MiniPick.is_picker_active()", 5000), "Find Action picker did not open")
	eq(child.lua_get("MiniPick.get_picker_opts().source.name"), "Find Action")
	eq(child.lua_get([[require("gleb.find_action").state.context.win]]), editor_win)
end

T["find-action: Find Action opens from its shortcut"] = function()
	child.lua([[vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))]])
	local editor_win = child.lua_get("vim.api.nvim_get_current_win()")
	child.type_keys("<M-A>")

	expect_find_action(editor_win)
end

T["find-action: Find Action is registered as an action"] = function()
	local editor_win = child.lua_get("vim.api.nvim_get_current_win()")
	local action = child.lua_get([[(function()
		local found = require("gleb.actions").state.applicator.catalog:get("find_action.open")
		return found and { id = found.id, title = found.title } or vim.NIL
	end)()]])
	eq(action, { id = "find_action.open", title = "Find Action..." })

	child.lua([[
		local found = require("gleb.actions").state.applicator.catalog:get("find_action.open")
		local ctx = require("gleb.actions.context").capture()
		vim.schedule(function() found.run(ctx) end)
	]])
	expect_find_action(editor_win)
end

return T
