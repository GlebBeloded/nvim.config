local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		TreeModel = require("gleb.ui.tree.model")
		TreeFold = require("gleb.ui.tree.fold")

		function TreeNodes(options)
			options = options or {}
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
					open_by_default = not options.fold_b,
					children = { { id = "B1" } },
				},
			}
		end

		function TreeRows(tree)
			return vim.tbl_map(function(row)
				return { row.id, row.depth }
			end, TreeModel.rows(tree))
		end
	]])
end

local T = H.child_set(child, start)

T["ui: Tree flattens open groups depth first"] = MiniTest.new_set()

T["ui: Tree flattens open groups depth first"]["hides descendants of the folded nested group"] = function()
	eq(
		child.lua_get([[(function()
		local tree = TreeModel.new(TreeNodes())
		TreeModel.set_open(tree, "A2", false)
		return TreeRows(tree)
	end)()]]),
		{
			{ "A", 0 },
			{ "A1", 1 },
			{ "A2", 1 },
			{ "B", 0 },
			{ "B1", 1 },
		}
	)
end

T["ui: Tree keeps fold state by id across rebuilds"] = MiniTest.new_set()

T["ui: Tree keeps fold state by id across rebuilds"]["keeps surviving ids and resets ids that return"] = function()
	eq(
		child.lua_get([[(function()
		local tree = TreeModel.new(TreeNodes())
		TreeModel.set_open(tree, "A2", false)

		local without_a1 = TreeNodes()
		table.remove(without_a1[1].children, 1)
		TreeModel.rebuild(tree, without_a1)
		local kept = TreeRows(tree)

		local without_a2 = TreeNodes()
		table.remove(without_a2[1].children, 2)
		TreeModel.rebuild(tree, without_a2)
		TreeModel.rebuild(tree, TreeNodes())

		return { kept = kept, restored = TreeRows(tree) }
	end)()]]),
		{
			kept = { { "A", 0 }, { "A2", 1 }, { "B", 0 }, { "B1", 1 } },
			restored = { { "A", 0 }, { "A1", 1 }, { "A2", 1 }, { "A21", 2 }, { "B", 0 }, { "B1", 1 } },
		}
	)
end

T["ui: Tree groups start in their default state"] = MiniTest.new_set()

T["ui: Tree groups start in their default state"]["uses each group's open-by-default value"] = function()
	eq(child.lua_get([[TreeRows(TreeModel.new(TreeNodes({ fold_b = true })))]]), {
		{ "A", 0 },
		{ "A1", 1 },
		{ "A2", 1 },
		{ "A21", 2 },
		{ "B", 0 },
	})
end

T["ui: Close on an open group folds it"] = MiniTest.new_set()

T["ui: Close on an open group folds it"]["keeps the group selected"] = function()
	eq(
		child.lua_get([[(function()
		local tree = TreeModel.new(TreeNodes())
		local selected = TreeFold.close(tree, "A2")
		return { selected = selected, rows = TreeRows(tree) }
	end)()]]),
		{
			selected = "A2",
			rows = { { "A", 0 }, { "A1", 1 }, { "A2", 1 }, { "B", 0 }, { "B1", 1 } },
		}
	)
end

T["ui: Close on a leaf folds its parent and selects it"] = MiniTest.new_set()

T["ui: Close on a leaf folds its parent and selects it"]["folds the nearest foldable ancestor"] = function()
	eq(
		child.lua_get([[(function()
		local tree = TreeModel.new(TreeNodes())
		local selected = TreeFold.close(tree, "A21")
		return { selected = selected, rows = TreeRows(tree) }
	end)()]]),
		{
			selected = "A2",
			rows = { { "A", 0 }, { "A1", 1 }, { "A2", 1 }, { "B", 0 }, { "B1", 1 } },
		}
	)
end

T["ui: Close on a folded group folds its parent"] = MiniTest.new_set()

T["ui: Close on a folded group folds its parent"]["selects the newly folded parent"] = function()
	eq(
		child.lua_get([[(function()
		local tree = TreeModel.new(TreeNodes())
		TreeModel.set_open(tree, "A2", false)
		local selected = TreeFold.close(tree, "A2")
		return { selected = selected, rows = TreeRows(tree) }
	end)()]]),
		{
			selected = "A",
			rows = { { "A", 0 }, { "B", 0 }, { "B1", 1 } },
		}
	)
end

T["ui: Open on a folded group unfolds it"] = MiniTest.new_set()

T["ui: Open on a folded group unfolds it"]["keeps the group selected"] = function()
	eq(
		child.lua_get([[(function()
		local tree = TreeModel.new(TreeNodes())
		TreeModel.set_open(tree, "A2", false)
		local selected = TreeFold.open(tree, "A2")
		return { selected = selected, rows = TreeRows(tree) }
	end)()]]),
		{
			selected = "A2",
			rows = { { "A", 0 }, { "A1", 1 }, { "A2", 1 }, { "A21", 2 }, { "B", 0 }, { "B1", 1 } },
		}
	)
end

T["ui: Open on an open group selects its first child"] = MiniTest.new_set()

T["ui: Open on an open group selects its first child"]["does not change the rows"] = function()
	eq(
		child.lua_get([[(function()
		local tree = TreeModel.new(TreeNodes())
		local selected = TreeFold.open(tree, "A")
		return { selected = selected, rows = TreeRows(tree) }
	end)()]]),
		{
			selected = "A1",
			rows = { { "A", 0 }, { "A1", 1 }, { "A2", 1 }, { "A21", 2 }, { "B", 0 }, { "B1", 1 } },
		}
	)
end

T["ui: Open on a leaf does nothing"] = MiniTest.new_set()

T["ui: Open on a leaf does nothing"]["keeps the rows and selection"] = function()
	eq(
		child.lua_get([[(function()
		local tree = TreeModel.new(TreeNodes())
		local before = TreeRows(tree)
		local selected = TreeFold.open(tree, "B1")
		return { before = before, selected = selected, after = TreeRows(tree) }
	end)()]]),
		{
			before = { { "A", 0 }, { "A1", 1 }, { "A2", 1 }, { "A21", 2 }, { "B", 0 }, { "B1", 1 } },
			selected = "B1",
			after = { { "A", 0 }, { "A1", 1 }, { "A2", 1 }, { "A21", 2 }, { "B", 0 }, { "B1", 1 } },
		}
	)
end

T["ui: Toggle on a leaf folds its parent"] = MiniTest.new_set()

T["ui: Toggle on a leaf folds its parent"]["selects the folded parent"] = function()
	eq(
		child.lua_get([[(function()
		local tree = TreeModel.new(TreeNodes())
		local selected = TreeFold.toggle(tree, "A1")
		return { selected = selected, rows = TreeRows(tree) }
	end)()]]),
		{
			selected = "A",
			rows = { { "A", 0 }, { "B", 0 }, { "B1", 1 } },
		}
	)
end

T["ui: Close all selects the top-level ancestor"] = MiniTest.new_set()

T["ui: Close all selects the top-level ancestor"]["open all keeps the resulting selection"] = function()
	eq(
		child.lua_get([[(function()
		local tree = TreeModel.new(TreeNodes())
		local selected = TreeFold.close_all(tree, "A21")
		local closed = TreeRows(tree)
		selected = TreeFold.open_all(tree, selected)
		return { closed = closed, selected = selected, opened = TreeRows(tree) }
	end)()]]),
		{
			closed = { { "A", 0 }, { "B", 0 } },
			selected = "A",
			opened = { { "A", 0 }, { "A1", 1 }, { "A2", 1 }, { "A21", 2 }, { "B", 0 }, { "B1", 1 } },
		}
	)
end

T["ui: A pinned group never folds"] = MiniTest.new_set()

T["ui: A pinned group never folds"]["ignores direct, ancestor and all-fold attempts"] = function()
	eq(
		child.lua_get([[(function()
		local tree = TreeModel.new({
			{
				id = "R",
				foldable = true,
				pinned = true,
				open_by_default = true,
				children = {
					{
						id = "A",
						foldable = true,
						open_by_default = true,
						children = { { id = "A1" } },
					},
				},
			},
		})

		local selected_root = TreeFold.close(tree, "R")
		local selected_parent = TreeFold.close(tree, "A1")
		local selected_pinned = TreeFold.close(tree, selected_parent)
		local selected_all = TreeFold.close_all(tree, "A1")
		return {
			selected = { selected_root, selected_parent, selected_pinned, selected_all },
			rows = TreeRows(tree),
		}
	end)()]]),
		{
			selected = { "R", "A", "A", "R" },
			rows = { { "R", 0 }, { "A", 1 } },
		}
	)
end

return T
