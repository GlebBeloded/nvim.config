-- Reference screenshots of the shared picker at its responsive breakpoints.
-- Update with `make screenshots` (UPDATE_SCREENSHOTS=1) after an intended change.
local H = require("tests.helpers")
local MiniTest = require("mini.test")

local child = H.new_child()
local eq = MiniTest.expect.equality

local ITEMS = {
	{ text = "vim.ui.select = function", secondary = "lua/gleb/select/init.lua:6", category = "Config" },
	{ text = "one shared picker UI", secondary = "openspec/changes/picker-ui/proposal.md:9", category = "UI" },
	{ text = 'require("gleb.picker")', secondary = "init.lua:17", category = "Startup" },
}

local function start()
	child.start_bare()
end

local T = H.child_set(child, start)

local function load_picker()
	eq(child.lua_get([[pcall(require, "gleb.picker")]]), true)
	child.lua(
		[[
		Picker = require("gleb.picker")
		MiniPick = require("mini.pick")
		PickerItems = ...

		function ShowResponsivePicker()
			Picker.start({
				title = "Live Grep",
				items = PickerItems,
				match = function(_, inds) return inds end,
			})
		end
	]],
		{ ITEMS }
	)
end

local function set_size(lines, columns)
	child.o.lines = lines
	child.o.columns = columns
end

T["picker: Compact picker matches reference screenshot"] = function()
	set_size(24, 60)
	load_picker()
	child.lua_notify([[ShowResponsivePicker()]])
	assert(child.wait([[MiniPick.is_picker_active()]]), "shared picker did not open")
	child.type_keys("picker")
	assert(child.wait([[table.concat(MiniPick.get_picker_query()) == "picker"]]), "query was not rendered")

	local text = table.concat(vim.tbl_map(table.concat, child.get_screenshot().text), "\n")
	eq(text:find("Config", 1, true), nil)
	eq(text:find("Open", 1, true), nil)
	eq(text:find("↩", 1, true) ~= nil, true)
	H.expect_screenshot(child.get_screenshot())
	child.type_keys("<Esc>")
end

T["picker: Narrow picker matches reference screenshot"] = function()
	set_size(24, 40)
	load_picker()
	child.lua_notify([[ShowResponsivePicker()]])
	assert(child.wait([[MiniPick.is_picker_active()]]), "shared picker did not open")
	child.type_keys("picker")
	assert(child.wait([[table.concat(MiniPick.get_picker_query()) == "picker"]]), "query was not rendered")

	local text = table.concat(vim.tbl_map(table.concat, child.get_screenshot().text), "\n")
	eq(text:find("vim.ui.select = function", 1, true) ~= nil, true)
	eq(text:find("lua/gleb/select", 1, true), nil)
	eq(text:find("↩", 1, true), nil)
	H.expect_screenshot(child.get_screenshot())
	child.type_keys("<Esc>")
end

T["picker: Short editor gives the picker full height"] = function()
	set_size(14, 80)
	load_picker()
	local config = child.lua_get([[require("gleb.picker.layout").window_config()]])

	eq(config.row, 0)
	eq(config.height, 12)
end

T["picker: Resize recomputes picker layout"] = function()
	set_size(24, 80)
	load_picker()
	child.lua_notify([[ShowResponsivePicker()]])
	assert(child.wait([[MiniPick.is_picker_active()]]), "shared picker did not open")
	set_size(24, 40)
	child.cmd("doautocmd VimResized")
	assert(
		child.wait([[vim.api.nvim_win_get_config(MiniPick.get_picker_state().windows.main).width == 38]]),
		"picker did not resize"
	)

	local config = child.lua_get([[vim.api.nvim_win_get_config(MiniPick.get_picker_state().windows.main)]])
	local lines = child.lua_get([[vim.api.nvim_buf_get_lines(MiniPick.get_picker_state().buffers.main, 0, -1, false)]])
	eq(config.width, 38)
	eq(config.col, 0)
	eq(lines[1], " vim.ui.select = function")
	local text = table.concat(vim.tbl_map(table.concat, child.get_screenshot().text), "\n")
	eq(text:find("↩", 1, true), nil)
	child.type_keys("<Esc>")
end

return T
