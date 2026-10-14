local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_config()
	child.wait_very_lazy()
	child.lua([[
		vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))
		local Context = require("gleb.actions.context")
		local Registry = require("gleb.actions.registry")
		local catalog = Registry.new({ {
			{
				id = "test.regular",
				title = "Regular Action",
				category = "Test",
				modes = { "n" },
				run = function(ctx)
					RegularRun = {
						win = vim.api.nvim_get_current_win(),
						buf = vim.api.nvim_get_current_buf(),
						cursor = vim.api.nvim_win_get_cursor(0),
						mode = vim.fn.mode(1),
						ctx = ctx,
					}
				end,
			},
			{
				id = "test.toggle",
				title = "Toggle Wrap",
				category = "Test",
				modes = { "n" },
				run = function() end,
				toggle = {
					get = function(ctx) return vim.wo[ctx.win].wrap end,
					set = function(_, value)
						ToggleWin = vim.api.nvim_get_current_win()
						vim.wo.wrap = value
					end,
				},
			},
			{
				id = "test.visual",
				title = "Visual Action",
				category = "Test",
				modes = { "x" },
				run = function(ctx)
					VisualRun = {
						win = vim.api.nvim_get_current_win(),
						buf = vim.api.nvim_get_current_buf(),
						mode = vim.fn.mode(1),
						selection = ctx.selection,
						anchor = vim.fn.getpos("v")[2],
						cursor = vim.api.nvim_win_get_cursor(0)[1],
					}
				end,
			},
		} })
		local actions = require("gleb.actions")
		actions.state.applicator.catalog = catalog
		actions.state.store.catalog = catalog
		actions.state.store.last_good = {
			["test.regular"] = { "gR" },
			["test.toggle"] = {},
			["test.visual"] = { "gV" },
		}
		vim.keymap.set("n", "gR", Context.invoke(catalog:get("test.regular")))
	]])
end

local T = H.child_set(child, start)

local function open_palette(keys)
	child.type_keys(keys or "<M-A>")
	assert(child.wait("MiniPick.is_picker_active()", 5000), "Find Action picker did not open")
	assert(child.wait("#MiniPick.get_picker_items() > 0", 5000), "Find Action items did not load")
end

T["find-action: Regular action runs like its shortcut"] = function()
	child.api.nvim_buf_set_lines(0, 0, -1, false, { "one", "two", "three" })
	child.api.nvim_win_set_cursor(0, { 2, 1 })
	child.type_keys("gR")
	local shortcut_run = child.lua_get([[RegularRun]])

	child.lua([[RegularRun = nil]])
	open_palette()
	child.type_keys("regular")
	child.type_keys("<CR>")
	assert(child.wait("RegularRun ~= nil", 5000), "Regular action did not run")

	eq(child.lua_get([[MiniPick.is_picker_active()]]), false)
	eq(child.lua_get([[RegularRun]]), shortcut_run)
end

T["find-action: Toggle changes without closing the palette"] = function()
	child.wo.wrap = false
	local editor_win = child.api.nvim_get_current_win()
	open_palette()
	child.type_keys("toggle")
	local selected = child.lua_get([[MiniPick.get_picker_matches().current_ind]])
	child.type_keys("<CR>")
	assert(child.wait("ToggleWin ~= nil", 5000), "Toggle action did not run")

	eq(child.lua_get([[MiniPick.is_picker_active()]]), true)
	eq(child.lua_get([[vim.wo[]] .. editor_win .. [[].wrap]]), true)
	eq(child.lua_get([[ToggleWin]]), editor_win)
	eq(child.lua_get([[MiniPick.get_picker_matches().current_ind]]), selected)
	eq(child.lua_get([[MiniPick.get_picker_matches().current.glyph]]), true)
end

T["find-action: Visual palette preserves the selection"] = function()
	child.api.nvim_buf_set_lines(0, 0, -1, false, { "one", "two", "three", "four" })
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	local editor_win = child.api.nvim_get_current_win()
	local editor_buf = child.api.nvim_get_current_buf()
	open_palette("Vj<M-A>")

	eq(
		child.lua_get([[
		vim.tbl_map(function(item) return item.text end, MiniPick.get_picker_items())
	]]),
		{ "other actions", "Visual Action" }
	)
	child.type_keys("<CR>")
	assert(child.wait("VisualRun ~= nil", 5000), "Visual action did not run")

	eq(child.lua_get([[VisualRun]]), {
		win = editor_win,
		buf = editor_buf,
		mode = "V",
		selection = { start = { 2, 0 }, finish = { 3, 0 } },
		anchor = 2,
		cursor = 3,
	})
end

return T
