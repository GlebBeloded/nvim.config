-- Reference screenshot of the shared wide picker frame.
-- Update with `make screenshots` (UPDATE_SCREENSHOTS=1) after an intended change.
local H = require("tests.helpers")
local MiniTest = require("mini.test")

local child = H.new_child()
local eq = MiniTest.expect.equality

local ITEMS = {
	{ text = "config matches", section = true },
	{ text = "vim.ui.select = function", secondary = "lua/gleb/select/init.lua:6", category = "Config" },
	{ text = "one shared picker UI", secondary = "openspec/changes/picker-ui/proposal.md:9", category = "UI" },
	{ text = 'require("gleb.picker")', secondary = "init.lua:17", category = "Startup" },
}

local MANY_ITEMS = {
	{ text = "first" },
	{ text = "second" },
	{ text = "third" },
	{ text = "fourth" },
	{ text = "fifth" },
	{ text = "sixth" },
}

local function start()
	child.start_bare({ "gruvbox-material" })
	child.o.lines = 24
	child.o.columns = 80
	child.cmd("colorscheme gruvbox-material")
end

local T = H.child_set(child, start)

local function expect_hint_tracks_picker()
	local geometry = child.lua_get([[(function()
		local main = require("mini.pick").get_picker_state().windows.main
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if vim.wo[win].winhighlight:find("Normal:PickerHint", 1, true) then
				return {
					hint = vim.api.nvim_win_get_config(win),
					position = vim.api.nvim_win_get_position(main),
					width = vim.api.nvim_win_get_width(main),
					height = vim.api.nvim_win_get_height(main),
				}
			end
		end
	end)()]])
	eq(geometry.hint.width, geometry.width)
	eq(geometry.hint.row, geometry.position[1] + geometry.height + 1)
	eq(geometry.hint.col, geometry.position[2])
end

T["picker: Wide picker matches reference screenshot"] = function()
	local loaded = child.lua_get([[(function()
		local ok, picker = pcall(require, "gleb.picker")
		if ok then Picker = picker end
		return ok
	end)()]])
	eq(loaded, true)

	child.lua_notify(
		[[Picker.start({
		title = "Live Grep",
		items = ...,
		hints = "Open ↩ · Split ⌃S · Vsplit ⌃V",
		match = function(_, inds) return inds end,
	})]],
		{ ITEMS }
	)
	assert(child.wait([[require("mini.pick").is_picker_active()]]), "shared picker did not open")
	child.type_keys("picker<Down>")
	assert(child.wait([[table.concat(require("mini.pick").get_picker_query()) == "picker"]]), "query was not rendered")

	H.expect_hl_colors(child, "MiniPickBorder", { fg = "#45403d" })
	H.expect_hl_colors(child, "MiniPickNormal", { fg = "#ddc7a1", bg = "#282828" })
	H.expect_hl_colors(child, "MiniPickMatchCurrent", { bg = "#32302f" })
	H.expect_hl_colors(child, "PickerHint", { fg = "#5a524c" })
	H.expect_screenshot(child.get_screenshot())
	child.type_keys("<Esc>")
end

T["picker: Focused match remains above the hint row"] = function()
	child.lua_notify(
		[[require("gleb.picker").start({
			title = "Many Matches",
			items = ...,
			hints = "Open ↵ · Split ⌃S · Vsplit ⌃V",
			match = function(_, inds) return inds end,
		})]],
		{ MANY_ITEMS }
	)
	assert(child.wait([[require("mini.pick").is_picker_active()]]), "shared picker did not open")
	child.type_keys("<Down><Down><Down><Down>")
	assert(child.wait([[require("mini.pick").get_picker_matches().current.text == "fifth"]]), "fifth match not focused")

	local lines = child.lua_get([[
		vim.api.nvim_buf_get_lines(require("mini.pick").get_picker_state().buffers.main, 0, -1, false)
	]])
	eq(vim.tbl_contains(lines, " fifth"), true)
	eq(#lines, 4)
	child.type_keys("<Esc>")
end

T["picker: Alternate picker views keep the border counter-free"] = function()
	child.lua_notify([[require("gleb.picker").start({
			title = "Alternate Views",
			items = { "first", "second" },
			match = function(_, inds) return inds end,
		})]])
	assert(child.wait([[require("mini.pick").is_picker_active()]]), "shared picker did not open")

	child.type_keys("<Tab>")
	assert(
		child.wait([[
		require("mini.pick").get_picker_state().buffers.main
			~= vim.api.nvim_win_get_buf(require("mini.pick").get_picker_state().windows.main)
	]]),
		"preview view did not open"
	)
	local preview_config =
		child.lua_get([[vim.api.nvim_win_get_config(require("mini.pick").get_picker_state().windows.main)]])
	eq(preview_config.footer, nil)
	child.type_keys("<C-n>")
	assert(child.wait([[require("mini.pick").get_picker_matches().current == "second"]]), "second match not focused")
	preview_config =
		child.lua_get([[vim.api.nvim_win_get_config(require("mini.pick").get_picker_state().windows.main)]])
	eq(preview_config.footer, nil)
	child.o.columns = 70
	child.cmd("doautocmd VimResized")
	assert(
		child.wait([[vim.api.nvim_win_get_config(require("mini.pick").get_picker_state().windows.main).width == 68]]),
		"preview view did not resize"
	)
	preview_config =
		child.lua_get([[vim.api.nvim_win_get_config(require("mini.pick").get_picker_state().windows.main)]])
	eq(preview_config.footer, nil)
	expect_hint_tracks_picker()

	child.type_keys("<S-Tab>")
	assert(
		child.wait([[
		require("mini.pick").get_picker_state().buffers.info
			== vim.api.nvim_win_get_buf(require("mini.pick").get_picker_state().windows.main)
	]]),
		"info view did not open"
	)
	local info_config =
		child.lua_get([[vim.api.nvim_win_get_config(require("mini.pick").get_picker_state().windows.main)]])
	eq(info_config.footer, nil)
	child.type_keys("<C-p>")
	assert(child.wait([[require("mini.pick").get_picker_matches().current == "first"]]), "first match not focused")
	info_config = child.lua_get([[vim.api.nvim_win_get_config(require("mini.pick").get_picker_state().windows.main)]])
	eq(info_config.footer, nil)
	child.o.columns = 80
	child.cmd("doautocmd VimResized")
	assert(
		child.wait([[vim.api.nvim_win_get_config(require("mini.pick").get_picker_state().windows.main).width == 70]]),
		"info view did not resize"
	)
	info_config = child.lua_get([[vim.api.nvim_win_get_config(require("mini.pick").get_picker_state().windows.main)]])
	eq(info_config.footer, nil)
	expect_hint_tracks_picker()
	child.type_keys("<Esc>")
end

T["picker: Source-specific hint band shows hints and counter"] = function()
	child.o.winborder = "rounded"
	child.lua_notify(
		[[require("gleb.picker").start({
			title = "Hint Band",
			items = ...,
			hints = "Open ↵ · Split ⌃S",
			hint_keys = { "↵", "⌃S" },
			hint_band = true,
			match = function(_, inds) return inds end,
		})]],
		{ MANY_ITEMS }
	)
	assert(child.wait([[require("mini.pick").is_picker_active()]]), "shared picker did not open")
	child.type_keys("<Down>")
	assert(
		child.wait([[require("mini.pick").get_picker_matches().current.text == "second"]]),
		"second match not focused"
	)

	local text = table.concat(vim.tbl_map(table.concat, child.get_screenshot().text), "\n")
	eq(text:find("Open ↵ · Split ⌃S", 1, true) ~= nil, true)
	eq(text:find("6/6", 1, true) ~= nil, true)
	eq(text:find("││ Open ↵ · Split ⌃S", 1, true), nil)
	eq(
		child.lua_get(
			[[vim.api.nvim_win_get_config(require("mini.pick").get_picker_state().windows.main).footer == nil]]
		),
		true
	)
	H.expect_hl_colors(child, "PickerHintBand", { bg = "#32302f" })
	H.expect_hl_colors(child, "PickerHintKey", { fg = "#ddc7a1", bg = "#32302f" })
end

return T
