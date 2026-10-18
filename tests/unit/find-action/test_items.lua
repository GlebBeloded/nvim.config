local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[FindActionItems = require("gleb.find_action.items")]])
end

local T = H.child_set(child, start)

T["find-action: Recent history keeps the last 20 actions"] = function()
	eq(
		child.lua_get([[
			(function()
				local path = vim.fs.joinpath(vim.fn.stdpath("state"), "find_action_recent.json")
				vim.fn.delete(path)
				local history = FindActionItems.history()
				for index = 1, 21 do
					history:record("test.action_" .. index)
				end
				return FindActionItems.history():load()
			end)()
		]]),
		{
			"test.action_21",
			"test.action_20",
			"test.action_19",
			"test.action_18",
			"test.action_17",
			"test.action_16",
			"test.action_15",
			"test.action_14",
			"test.action_13",
			"test.action_12",
			"test.action_11",
			"test.action_10",
			"test.action_9",
			"test.action_8",
			"test.action_7",
			"test.action_6",
			"test.action_5",
			"test.action_4",
			"test.action_3",
			"test.action_2",
		}
	)
end

T["find-action: Query matches all searchable fields"] = function()
	eq(
		child.lua_get([[
			(function()
				local actions = {
					{
						id = "git.open_diffview",
						title = "Open Diffview",
						category = "Git | Diff",
						aliases = { "compare.changes" },
						run = function() end,
					},
					{ id = "edit.format", title = "Format Buffer", category = "Code", run = function() end },
				}
				local ids = function(query)
					return vim.tbl_map(function(action) return action.id end, FindActionItems.match(actions, query))
				end
				return { ids("opdf"), ids("gtdf"), ids("cmpch") }
			end)()
		]]),
		{
			{ "git.open_diffview" },
			{ "git.open_diffview" },
			{ "git.open_diffview" },
		}
	)
end

T["find-action: Multi-word query spans category and title"] = function()
	eq(
		child.lua_get([[
			(function()
				local actions = {
					{ id = "file_tree.open", title = "Open", category = "Project", run = function() end },
				}
				local ids = function(query)
					return vim.tbl_map(function(action) return action.id end, FindActionItems.match(actions, query))
				end
				return { ids("project open"), ids("open project"), ids("project"), ids("open") }
			end)()
		]]),
		{
			{ "file_tree.open" },
			{},
			{ "file_tree.open" },
			{ "file_tree.open" },
		}
	)
end

return T
