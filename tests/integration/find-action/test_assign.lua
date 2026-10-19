local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_config()
	child.wait_very_lazy()
	child.lua([[
		local Actions = require("gleb.actions")
		ShortcutPath = vim.fn.tempname()
		TargetRuns = 0
		FixtureActions = {
			{
				id = "test.target",
				title = "Target Action",
				category = "Test",
				run = function() TargetRuns = TargetRuns + 1 end,
			},
			{
				id = "test.other",
				title = "Other Action",
				category = "Test",
				run = function() end,
			},
			{
				id = "lazy.close",
				title = "Adapter Action",
				category = "Test",
				run = function() end,
			},
		}
		Actions.setup({ FixtureActions }, ShortcutPath)
		Actions.state.store:save({
			["test.target"] = {},
			["test.other"] = { "<F21>" },
			["lazy.close"] = {},
		})
		Actions.state.applicator:apply(Actions.state.store.last_good)
		vim.keymap.set("n", "<M-A>", require("gleb.find_action").open)
		Notifications = {}
		vim.notify = function(message, level)
			table.insert(Notifications, { message = message, level = level })
		end
	]])
end

local T = H.child_set(child, start)

local function open_action(query)
	child.type_keys("<M-A>")
	assert(child.wait("MiniPick.is_picker_active()", 5000), "Find Action picker did not open")
	assert(child.wait("#MiniPick.get_picker_items() > 0", 5000), "Find Action items did not load")
	child.type_keys(query)
	assert(child.wait("MiniPick.get_picker_matches().current ~= nil", 5000), "Action did not match")
end

local function shortcut_map()
	return child.lua_get([[require("gleb.actions").state.store.last_good]])
end

local function reset_shortcuts()
	child.lua([[
		local actions = require("gleb.actions")
		actions.state.store:save({
			["test.target"] = {},
			["test.other"] = { "<F21>" },
			["lazy.close"] = {},
		})
		actions.state.applicator:apply(actions.state.store.last_good)
	]])
end

local function assign(keys)
	child.type_keys("<M-}>")
	child.type_keys(keys)
end

T["find-action: Assign float captures a free shortcut"] = function()
	open_action("target")
	local palette_win = child.lua_get([[MiniPick.get_picker_state().windows.main]])
	assign("gZ")
	assert(child.wait([[vim.api.nvim_get_current_win() ~= ]] .. palette_win, 5000), "Assign float did not take focus")

	eq(
		child.lua_get([[
			table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"):match("gZ")
		]]),
		"gZ"
	)
	child.type_keys("<CR>")
	assert(child.wait([[vim.api.nvim_get_current_win() == ]] .. palette_win, 5000), "Focus did not return to palette")

	eq(child.lua_get([[MiniPick.is_picker_active()]]), true)
	eq(shortcut_map()["test.target"], { "gZ" })
end

T["find-action: Assignment can be cancelled"] = function()
	open_action("target")
	local before = shortcut_map()
	assign("gZ<Esc>")
	assert(
		child.wait([[vim.api.nvim_get_current_win() == MiniPick.get_picker_state().windows.main]], 5000),
		"Focus did not return to palette"
	)

	eq(child.lua_get([[MiniPick.is_picker_active()]]), true)
	eq(shortcut_map(), before)
end

T["find-action: Conflict choices have distinct outcomes"] = function()
	open_action("target")
	assign("<F21><CR>r")
	assert(
		child.wait([[require("gleb.actions").state.store.last_good["test.target"][1] == "<F21>"]], 5000),
		"Remove other did not save"
	)
	eq(shortcut_map(), {
		["test.target"] = { "<F21>" },
		["lazy.close"] = {},
	})

	child.type_keys("<Esc>")
	reset_shortcuts()
	open_action("target")
	assign("<F21><CR>k")
	assert(
		child.wait([[require("gleb.actions").state.store.last_good["test.target"][1] == "<F21>"]], 5000),
		"Keep both did not save"
	)
	eq(shortcut_map(), {
		["test.target"] = { "<F21>" },
		["test.other"] = { "<F21>" },
		["lazy.close"] = {},
	})

	child.type_keys("<Esc>")
	open_action("adapter")
	assign("<F21><CR>")
	assert(
		child.wait([[vim.api.nvim_get_current_win() ~= MiniPick.get_picker_state().windows.main]], 5000),
		"Third assignment conflict did not open"
	)
	local conflict_text = child.lua_get([[table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")]])
	eq(conflict_text:find("Target Action", 1, true) ~= nil, true)
	eq(conflict_text:find("Other Action", 1, true) ~= nil, true)
	child.type_keys("r")
	assert(
		child.wait([[require("gleb.actions").state.store.last_good["lazy.close"][1] == "<F21>"]], 5000),
		"Multi-conflict removal did not save"
	)
	eq(shortcut_map(), { ["lazy.close"] = { "<F21>" } })

	child.type_keys("<Esc>")
	reset_shortcuts()
	open_action("target")
	assign("<F21><CR>c")
	assert(
		child.wait([[vim.api.nvim_get_current_win() == MiniPick.get_picker_state().windows.main]], 5000),
		"Conflict cancel did not return focus"
	)
	eq(shortcut_map(), {
		["test.target"] = {},
		["test.other"] = { "<F21>" },
		["lazy.close"] = {},
	})
end

T["find-action: Saved shortcut applies immediately"] = function()
	open_action("target")
	assign("<F22><CR>")
	assert(
		child.wait([[require("gleb.actions").state.store.last_good["test.target"][1] == "<F22>"]], 5000),
		"Shortcut was not saved"
	)
	child.type_keys("<Esc><F22>")
	assert(child.wait("TargetRuns == 1", 5000), "Saved shortcut did not run")

	eq(child.lua_get([[TargetRuns]]), 1)
	eq(child.lua_get([[table.concat(vim.fn.readfile(ShortcutPath), "\n"):match('"test.target"') ~= nil]]), true)
end

T["find-action: Adapter assignment reports deferred application"] = function()
	open_action("adapter")
	assign("<F23><CR>")
	assert(child.wait("#Notifications > 0", 5000), "Adapter notice was not reported")

	eq(shortcut_map()["lazy.close"], { "<F23>" })
	eq(child.lua_get([=[Notifications[#Notifications]]=]), {
		message = "Shortcut saved; applies when lazy reopens",
		level = vim.log.levels.INFO,
	})
end

return T
