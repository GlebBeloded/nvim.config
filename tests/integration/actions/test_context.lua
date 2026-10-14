local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		Context = require("gleb.actions.context")
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha", "beta", "gamma", "delta" })
	]])
end

local T = H.child_set(child, start)

T["actions: Invocation captures editor state"] = function()
	child.lua([[
		vim.api.nvim_win_set_cursor(0, { 2, 1 })
		Captured = Context.capture()
	]])

	eq(child.lua_get([[Captured.win]]), child.lua_get([[vim.api.nvim_get_current_win()]]))
	eq(child.lua_get([[Captured.buf]]), child.lua_get([[vim.api.nvim_get_current_buf()]]))
	eq(child.lua_get([[Captured.cursor]]), { 2, 1 })
	eq(child.lua_get([[Captured.mode]]), "n")
end

T["actions: Actions run in the invocation window"] = function()
	child.lua([[
		SourceWindow = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_cursor(SourceWindow, { 3, 2 })
		Captured = Context.capture()
		vim.cmd("vsplit")
		OtherWindow = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_cursor(SourceWindow, { 1, 0 })
		Context.run({ run = function(ctx)
			RunState = {
				win = vim.api.nvim_get_current_win(),
				cursor = vim.api.nvim_win_get_cursor(0),
				ctx = ctx,
			}
		end }, Captured)
	]])

	eq(child.lua_get([[RunState.win]]), child.lua_get([[SourceWindow]]))
	eq(child.lua_get([[RunState.cursor]]), { 3, 2 })
	eq(child.lua_get([[RunState.ctx == Captured]]), true)
	eq(child.lua_get([[vim.api.nvim_get_current_win()]]), child.lua_get([[SourceWindow]]))
end

T["actions: Visual actions restore the selection"] = function()
	child.lua([[
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		vim.cmd("normal! V2j")
		Captured = Context.capture()
		vim.cmd('execute "normal! \\<Esc>"')
		vim.api.nvim_win_set_cursor(0, { 4, 0 })
		Context.run({ run = function(ctx)
			RunState = {
				mode = vim.fn.mode(1),
				start = vim.api.nvim_buf_get_mark(0, "<"),
				finish = vim.api.nvim_buf_get_mark(0, ">"),
				ctx = ctx,
			}
		end }, Captured)
	]])

	eq(child.lua_get([[Captured.selection]]), { start = { 1, 0 }, finish = { 3, 0 } })
	eq(child.lua_get([[RunState.mode]]), "V")
	eq(child.lua_get([[RunState.start]]), { 1, 0 })
	eq(child.lua_get([[RunState.finish]]), { 3, child.lua_get([[vim.v.maxcol]]) })
	eq(child.lua_get([[RunState.ctx == Captured]]), true)
end

T["actions: Availability and toggles share the context"] = function()
	child.lua([[
		Captured = Context.capture()
		Seen = {}
		Action = {
			when = function(ctx) Seen.when_ctx = ctx; return true end,
			run = function(ctx) Seen.run_ctx = ctx end,
			toggle = {
				get = function(ctx) Seen.get_ctx = ctx; return false end,
				set = function(ctx, value) Seen.set_ctx = ctx; Seen.value = value end,
			},
		}
		Available = Context.is_available(Action, Captured)
		ToggleValue = Context.get_toggle(Action, Captured)
		Context.set_toggle(Action, Captured, true)
		Context.run(Action, Captured)
	]])

	eq(child.lua_get([[Available]]), true)
	eq(child.lua_get([[ToggleValue]]), false)
	eq(child.lua_get([[Seen.value]]), true)
	eq(
		child.lua_get([[
		Seen.when_ctx == Captured and Seen.get_ctx == Captured
			and Seen.set_ctx == Captured and Seen.run_ctx == Captured
	]]),
		true
	)
end

return T
