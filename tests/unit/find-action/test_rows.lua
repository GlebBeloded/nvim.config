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

T["find-action: Rows normalize shortcut spellings"] = function()
	eq(
		child.lua_get([[
			vim.tbl_map(function(lhs)
				return FindActionRows.format({
					id = "test." .. lhs,
					title = "Action",
					category = "Test",
					run = function() end,
				}, { lhs }).secondary
			end, { "<A-F>", "<C-h>", "<M-H>", "<C-S>", "<A-z>" })
		]]),
		{ "⌘⇧F", "⌘H", "⌘⇧H", "⌃S", "<M-z>" }
	)
end

T["find-action: Toggle rows show state glyphs"] = function()
	local rows = child.lua_get([[
		(function()
			local actions = require("gleb.view.actions")
			return {
				FindActionRows.format(actions[1], nil, true),
				FindActionRows.format(actions[2], nil, false),
			}
		end)()
	]])

	eq(rows, {
		{ text = "Soft Wrap", category = "View | Editor", glyph = true },
		{ text = "Spell Check", category = "View | Editor", glyph = false },
	})
end

return T
