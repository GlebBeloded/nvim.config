local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, function()
	child.start_bare()
end)

T["ui: Tree fold keys are the same in every tree"] = MiniTest.new_set()

T["ui: Tree fold keys are the same in every tree"]["uses each area's factory action ids"] = function()
	eq(
		child.lua_get([[(function()
		local ok, actions = pcall(require, "gleb.ui.tree.actions")
		if not ok then return { error = actions } end
		local factory = actions.fold_actions
		local shortcuts = vim.json.decode(table.concat(vim.fn.readfile(
			vim.fs.joinpath(vim.fn.stdpath("config"), "settings/keymap.json")), "\n"))
		local areas = {
			file_tree = { category = "Project", ft = "gleb-file-tree", toggle_id = "file_tree.toggle_fold" },
			changes = { category = "Changes", ft = "gleb-changes", toggle_id = "changes.toggle_fold" },
			references = { category = "References", ft = "gleb-references", toggle_id = "references.fold" },
		}
		local result = {}
		for area, options in pairs(areas) do
			options.area = area
			local actions = factory(options)
			local by_title = {}
			for _, action in ipairs(actions) do
				by_title[action.title] = shortcuts[action.id]
			end
			result[area] = by_title
		end
		return result
	end)()]]),
		{
			file_tree = {
				["Collapse Node"] = { "h", "<Left>", "zc", "<BS>" },
				["Expand Node"] = { "l", "<Right>", "zo" },
				["Toggle Fold"] = { "za" },
				["Fold All"] = { "zM" },
				["Unfold All"] = { "zR" },
			},
			changes = {
				["Collapse Node"] = { "h", "<Left>", "zc" },
				["Expand Node"] = { "l", "<Right>", "zo" },
				["Toggle Fold"] = { "za" },
				["Fold All"] = { "zM" },
				["Unfold All"] = { "zR" },
			},
			references = {
				["Collapse Node"] = { "h", "<Left>", "zc" },
				["Expand Node"] = { "l", "<Right>", "zo" },
				["Toggle Fold"] = { "za" },
				["Fold All"] = { "zM" },
				["Unfold All"] = { "zR" },
			},
		}
	)
end

return T
