local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[FindActionRows = require("gleb.find_action.rows")]])
end

local T = H.child_set(child, start)

T["find-action: Rows show action metadata"] = function()
	eq(
		child.lua_get([[
			FindActionRows.format({
				id = "git.open_differ",
				title = "Open Differ",
				category = "Git | Diff",
				run = function() end,
			}, { "<M-g>", "gd" })
		]]),
		{ text = "Open Differ", secondary = "⌘G", category = "Git | Diff" }
	)
end

T["find-action: Rows fall back to Vim notation"] = function()
	eq(
		child.lua_get([[
			FindActionRows.format({
				id = "edit.definition",
				title = "Go to Definition",
				category = "Navigate",
				run = function() end,
			}, { "gd" })
		]]),
		{ text = "Go to Definition", secondary = "gd", category = "Navigate" }
	)
end

T["find-action: Toggle rows show state glyphs"] = function()
	local rows = child.lua_get([[
		{
			FindActionRows.format({
				id = "view.wrap",
				title = "Soft Wrap",
				category = "View | Editor",
				run = function() end,
			}, nil, true),
			FindActionRows.format({
				id = "view.spell",
				title = "Spell Check",
				category = "View | Editor",
				run = function() end,
			}, nil, false),
		}
	]])

	eq(rows, {
		{ text = "Soft Wrap", category = "View | Editor", glyph = true },
		{ text = "Spell Check", category = "View | Editor", glyph = false },
	})
end

return T
