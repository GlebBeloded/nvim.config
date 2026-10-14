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
	eq(child.lua_get([[pcall(require, "gleb.picker.layout")]]), true)
	child.lua(
		[[
		PickerLayout = require("gleb.picker.layout")
		PickerRows = require("gleb.picker.rows")
		PickerItems = ...

		function ShowResponsivePicker()
			local config = PickerLayout.window_config()
			local buf = vim.api.nvim_create_buf(false, true)
			local win = vim.api.nvim_open_win(buf, true, vim.tbl_extend("force", config, {
				style = "minimal",
				border = "rounded",
				title = " Live Grep › picker ",
				title_pos = "left",
			}))
			PickerRows.show(buf, PickerItems, {})
			local hint = PickerLayout.hint()
			if hint then
				local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
				while #lines < config.height - 2 do
					table.insert(lines, "")
				end
				table.insert(lines, string.rep("─", config.width))
				table.insert(lines, string.rep(" ", math.max(config.width - vim.fn.strdisplaywidth(hint), 0)) .. hint)
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
			end
			vim.cmd("redraw")
			ResponsivePicker = { buf = buf, win = win }
			return ResponsivePicker
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
	child.lua([[ShowResponsivePicker()]])

	local text = table.concat(vim.tbl_map(table.concat, child.get_screenshot().text), "\n")
	eq(text:find("Config", 1, true), nil)
	eq(text:find("Open", 1, true), nil)
	eq(
		child.lua_get([=[vim.api.nvim_buf_get_lines(ResponsivePicker.buf, -2, -1, false)[1]]=]):find("↩", 1, true)
			~= nil,
		true
	)
	H.expect_screenshot(child.get_screenshot())
end

T["picker: Narrow picker matches reference screenshot"] = function()
	set_size(24, 40)
	load_picker()
	child.lua([[ShowResponsivePicker()]])

	local text = table.concat(vim.tbl_map(table.concat, child.get_screenshot().text), "\n")
	eq(text:find("vim.ui.select = function", 1, true) ~= nil, true)
	eq(text:find("lua/gleb/select", 1, true), nil)
	eq(text:find("↩", 1, true), nil)
	H.expect_screenshot(child.get_screenshot())
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
	child.lua([[ShowResponsivePicker()]])
	set_size(24, 40)
	child.cmd("doautocmd VimResized")
	child.lua([[
		vim.api.nvim_win_set_config(ResponsivePicker.win, PickerLayout.window_config())
		PickerRows.show(ResponsivePicker.buf, PickerItems, {})
	]])

	local config = child.lua_get([[vim.api.nvim_win_get_config(ResponsivePicker.win)]])
	local lines = child.lua_get([[vim.api.nvim_buf_get_lines(ResponsivePicker.buf, 0, -1, false)]])
	eq(config.width, 38)
	eq(config.col, 0)
	eq(lines[1], "vim.ui.select = function")
end

return T
