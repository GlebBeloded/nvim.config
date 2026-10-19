local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		TreeModel = require("gleb.ui.tree.model")
		local view_ok
		view_ok, TreeView = pcall(require, "gleb.ui.tree.view")
		if not view_ok then TreeViewError = TreeView end

		function TreeNodes()
			return {
				{
					id = "A",
					foldable = true,
					open_by_default = true,
					children = {
						{ id = "A1" },
						{
							id = "A2",
							foldable = true,
							open_by_default = true,
							children = { { id = "A21" } },
						},
					},
				},
				{
					id = "B",
					foldable = true,
					open_by_default = true,
					children = { { id = "B1" } },
				},
			}
		end

		function DrawTree(tree)
			TreeView.draw(tree, function(buf, rows)
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.tbl_map(function(row)
					return row.id
				end, rows))
			end)
		end
	]])
end

local T = H.child_set(child, start)

T["ui: Selection follows its id after a rebuild"] = MiniTest.new_set()

T["ui: Selection follows its id after a rebuild"]["tracks the selected node after an earlier sibling is inserted"] = function()
	eq(
		child.lua_get([[(function()
		if TreeViewError then return { error = TreeViewError } end
		local tree = TreeModel.new(TreeNodes())
		TreeView.attach(0, tree)
		DrawTree(tree)
		vim.api.nvim_win_set_cursor(0, { 6, 0 })

		local rebuilt = TreeNodes()
		table.insert(rebuilt, 2, { id = "X" })
		TreeModel.rebuild(tree, rebuilt)
		DrawTree(tree)

		local cursor = vim.api.nvim_win_get_cursor(0)
		return { cursor[1], vim.api.nvim_get_current_line() }
	end)()]]),
		{ 7, "B1" }
	)
end

T["ui: Selection on a hidden node moves to its visible ancestor"] = MiniTest.new_set()

T["ui: Selection on a hidden node moves to its visible ancestor"]["selects the nearest ancestor still drawn"] = function()
	eq(
		child.lua_get([[(function()
		if TreeViewError then return { error = TreeViewError } end
		local tree = TreeModel.new(TreeNodes())
		TreeView.attach(0, tree)
		DrawTree(tree)
		vim.api.nvim_win_set_cursor(0, { 4, 0 })

		TreeModel.set_open(tree, "A", false)
		DrawTree(tree)

		local cursor = vim.api.nvim_win_get_cursor(0)
		return { cursor[1], vim.api.nvim_get_current_line() }
	end)()]]),
		{ 1, "A" }
	)
end

return T
