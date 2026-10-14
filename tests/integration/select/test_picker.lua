local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare({ "nui.nvim" })
	child.lua([[
		MiniPick = require("mini.pick")
		MiniPick.setup()
		vim.ui.select = function(...) DefaultSelectArgs = { n = select("#", ...), ... } end
		require("gleb.select")
	]])
end

local T = H.child_set(child, start)

local function open_select(items, opts, callback)
	child.lua_notify(
		[[local items, opts = ...
		SelectCallOk, SelectCallError = pcall(vim.ui.select, items, opts, function(item, index) ]]
			.. callback
			.. [[ end)]],
		{ items, opts or vim.NIL }
	)
	assert(
		child.wait("MiniPick.is_picker_active()"),
		"shared picker did not open: " .. tostring(child.lua_get("SelectCallError"))
	)
end

T["select: Shared code action uses picker mappings"] = function()
	open_select({ "fix" }, { kind = "codeaction", prompt = "Code Actions" }, "Choice = { item, index }")
	local mappings = child.lua_get([[(function()
		local mappings = MiniPick.get_picker_opts().mappings
		return {
			mappings.move_down,
			mappings.focus_next_down.char,
			mappings.focus_next_tab.char,
			mappings.move_up,
			mappings.focus_previous_up.char,
			mappings.focus_previous_tab.char,
			mappings.stop,
			mappings.close_control_c.char,
			mappings.choose,
			mappings.submit_space.char,
		}
	end)()]])
	eq(mappings, { "j", "<Down>", "<Tab>", "k", "<Up>", "<S-Tab>", "<Esc>", "<C-c>", "<CR>", "<Space>" })
	local config = child.lua_get([[vim.api.nvim_win_get_config(MiniPick.get_picker_state().windows.main)]])
	eq(config.footer, nil)
	eq(config.title[1][1]:find("Code Actions", 1, true) ~= nil, true)
	child.type_keys("<Esc>")
end

T["select: General selection keeps text input mappings"] = function()
	open_select({ "j k" }, {}, "Choice = { item, index }")
	child.type_keys("j k")
	eq(child.wait([[table.concat(MiniPick.get_picker_query()) == "j k"]]), true)
	child.type_keys("<Esc>")
end

T["select: Omitted options open shared selection"] = function()
	child.lua_notify([[
		SelectOk, SelectError = pcall(vim.ui.select, { "x" }, nil, function() end)
	]])

	eq(child.wait("MiniPick.is_picker_active()"), true)
	child.type_keys("<Esc>")
	eq(child.wait("SelectOk ~= nil"), true)
	eq(child.lua_get("SelectOk"), true)
	eq(child.lua_get("SelectError"), vim.NIL)
end

T["select: Shared code action cancellation preserves callback arity"] = function()
	open_select(
		{ "fix" },
		{ kind = "codeaction" },
		[[
		CancelCalls = (CancelCalls or 0) + 1
		CancelArgs = { count = select("#", item, index), item_is_nil = item == nil, index_is_nil = index == nil }
	]]
	)

	child.type_keys("<Esc>")
	eq(child.wait("CancelCalls ~= nil"), true)
	eq(child.lua_get("CancelCalls"), 1)
	eq(child.lua_get("CancelArgs"), { count = 2, item_is_nil = true, index_is_nil = true })
end

T["select: Selection callback runs in the target window"] = function()
	child.lua([[SelectTarget = { win = vim.api.nvim_get_current_win(), buf = vim.api.nvim_get_current_buf() }]])
	open_select(
		{ "fix" },
		{ kind = "codeaction" },
		[[
		ChoiceContext = { win = vim.api.nvim_get_current_win(), buf = vim.api.nvim_get_current_buf(), item = item, index = index }
	]]
	)
	child.type_keys("<CR>")
	eq(child.wait("ChoiceContext ~= nil"), true)
	local context = child.lua_get([[{ target = SelectTarget, choice = ChoiceContext }]])
	eq(context.choice, { win = context.target.win, buf = context.target.buf, item = "fix", index = 1 })
end

T["select: Formatted code action width configures shared picker"] = function()
	local result = child.lua_get([[(function()
		vim.o.columns = 80
		local ok, select = pcall(require, "gleb.picker.select")
		if not ok then return { ok = false } end
		return { ok = true, widths = {
			select.window_config({ "x", "longer action" }, { prompt = "Apply", format_item = string.upper }).width,
			select.window_config({ string.rep("x", 100) }, { prompt = "Apply" }).width,
		} }
	end)()]])

	eq(result.ok, true)
	eq(result.widths, { 15, 76 })
end

T["select: Selection previews the current item"] = function()
	child.lua_notify([[
		vim.ui.select({ "one", "two" }, {
			format_item = function(item) return "formatted " .. item end,
			preview_item = function(item) Previewed = item end,
		}, function() end)
	]])
	assert(child.wait("MiniPick.is_picker_active()"), "shared picker did not open")
	eq(child.wait([[MiniPick.get_picker_matches().current ~= nil]]), true)

	local buf = child.lua_get([[MiniPick.get_picker_state().buffers.main]])
	eq(child.api.nvim_buf_get_lines(buf, 0, -1, false)[1], " formatted one")
	child.type_keys("<Down>")
	eq(child.wait([[Previewed == "two"]]), true)
	child.type_keys("<Esc>")
end

return T
