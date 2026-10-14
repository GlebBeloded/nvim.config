local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		Capture = require("gleb.actions.capture")
		Registry = require("gleb.actions.registry")
	]])
end

local T = H.child_set(child, start)

T["actions: Enter finishes a normalized key sequence"] = function()
	child.lua([[
		Keys = { vim.keycode("<C-a>"), "g", vim.keycode("<CR>") }
		Captured = Capture.capture(function() return table.remove(Keys, 1) end)
	]])

	eq(child.lua_get([[Captured]]), "<C-A>g")
end

T["actions: Esc cancels capture"] = function()
	child.lua([[
		Keys = { "g", vim.keycode("<Esc>") }
		Captured = Capture.capture(function() return table.remove(Keys, 1) end)
	]])

	eq(child.lua_get([[Captured == nil]]), true)
end

T["actions: Backspace removes the last captured key"] = function()
	child.lua([[
		Keys = { "g", "a", vim.keycode("<BS>"), vim.keycode("<CR>") }
		Captured = Capture.capture(function() return table.remove(Keys, 1) end)
	]])

	eq(child.lua_get([[Captured]]), "g")
end

T["actions: Exact and prefix overlaps conflict in one scope"] = function()
	child.lua([[
		Catalog = Registry.new({ {
			{ id = "edit.target", title = "Target", category = "Edit", run = function() end },
			{ id = "edit.open", title = "Open", category = "Edit", run = function() end },
			{ id = "edit.open_all", title = "Open All", category = "Edit", run = function() end },
		} })
		Conflicts = Capture.conflicts(Catalog, {
			["edit.open"] = { "g" },
			["edit.open_all"] = { "gg" },
		}, "edit.target", "g")
	]])

	eq(child.lua_get([[Conflicts]]), {
		{ action_id = "edit.open", lhs = "g", proposed_lhs = "g" },
		{ action_id = "edit.open_all", lhs = "gg", proposed_lhs = "g" },
	})
end

T["actions: Separate scopes do not conflict"] = function()
	child.lua([[
		Catalog = Registry.new({ {
			{
				id = "edit.lua_target",
				title = "Lua Target",
				category = "Edit",
				ft = "lua",
				run = function() end,
			},
			{
				id = "edit.visual",
				title = "Visual",
				category = "Edit",
				modes = { "x" },
				run = function() end,
			},
			{
				id = "edit.markdown",
				title = "Markdown",
				category = "Edit",
				ft = "markdown",
				run = function() end,
			},
		} })
		Conflicts = Capture.conflicts(Catalog, {
			["edit.visual"] = { "g" },
			["edit.markdown"] = { "g" },
		}, "edit.lua_target", "g")
	]])

	eq(child.lua_get([[Conflicts]]), {})
end

return T
