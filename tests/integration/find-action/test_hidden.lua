local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_config()
	child.wait_very_lazy()
	child.lua([[
		local Registry = require("gleb.actions.registry")
		local catalog = Registry.new({ {
			{ id = "test.visible", title = "Visible Action", category = "Test", run = function() end },
			{
				id = "test.hidden_mode",
				title = "Hidden Mode Action",
				category = "Test",
				modes = { "x" },
				run = function() end,
			},
			{
				id = "test.hidden_filetype",
				title = "Hidden Filetype Action",
				category = "Test",
				ft = "lua",
				run = function() end,
			},
			{
				id = "test.hidden_condition",
				title = "Hidden Condition Action",
				category = "Test",
				when = function() return false end,
				run = function() end,
			},
		} }, { complete_commands = function() return { "TestHiddenCommand" } end })
		local actions = require("gleb.actions")
		actions.state.applicator.catalog = catalog
		actions.state.store.catalog = catalog
		vim.bo.filetype = "text"
	]])
end

local T = H.child_set(child, start)

local function open_palette()
	child.type_keys("<M-A>")
	assert(child.wait("MiniPick.is_picker_active()", 5000), "Find Action picker did not open")
	assert(child.wait("#MiniPick.get_picker_items() > 0", 5000), "Find Action items did not load")
end

local function item_texts(expression)
	expression = expression or "MiniPick.get_picker_items()"
	return child.lua_get([[
		vim.tbl_map(function(item) return item.text end, ]] .. expression .. [[)
	]])
end

T["find-action: Hidden and unavailable actions start absent"] = function()
	open_palette()

	eq(item_texts(), { "Visible Action" })
end

T["find-action: Show hidden reveals a separate tier"] = function()
	open_palette()
	child.type_keys("hidden")
	eq(child.lua_get([[table.concat(MiniPick.get_picker_query())]]), "hidden")

	child.type_keys("<M-A>")
	assert(child.wait("#MiniPick.get_picker_matches().all == 5", 5000), "Hidden actions did not appear")

	eq(child.lua_get([[table.concat(MiniPick.get_picker_query())]]), "hidden")
	eq(item_texts("MiniPick.get_picker_matches().all"), {
		"More results",
		"Hidden Mode Action",
		"Hidden Filetype Action",
		"Hidden Condition Action",
		"Test Hidden Command",
	})
end

T["find-action: Hidden commands cannot be assigned"] = function()
	open_palette()
	child.type_keys("testhiddencommand")
	child.type_keys("<M-A>")
	assert(child.wait("#MiniPick.get_picker_matches().all == 2", 5000), "Hidden command did not appear")
	child.type_keys("j")

	local query = child.lua_get([[table.concat(MiniPick.get_picker_query())]])
	local windows = child.lua_get([[#vim.api.nvim_list_wins()]])
	local shortcut_file = child.lua_get([[vim.fn.readfile(require("gleb.actions").state.store.path)]])
	child.type_keys("<M-}>")

	eq(child.lua_get([[MiniPick.is_picker_active()]]), true)
	eq(child.lua_get([[table.concat(MiniPick.get_picker_query())]]), query)
	eq(child.lua_get([[#vim.api.nvim_list_wins()]]), windows)
	eq(child.lua_get([[vim.fn.readfile(require("gleb.actions").state.store.path)]]), shortcut_file)
end

return T
