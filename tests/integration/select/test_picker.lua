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
	local result = child.lua_get([[(function()
		local ok, select = pcall(require, "gleb.picker.select")
		return { ok = ok, keymap = ok and select.default_keymap() or nil }
	end)()]])

	eq(result.ok, true)
	eq(result.keymap, {
		focus_next = { "j", "<Down>", "<Tab>" },
		focus_prev = { "k", "<Up>", "<S-Tab>" },
		close = { "<Esc>", "<C-c>" },
		submit = { "<CR>", "<Space>" },
	})

	open_select({ "fix" }, { kind = "codeaction", prompt = "Code Actions" }, "Choice = { item, index }")
	local mappings = child.lua_get([[(function()
		local mappings = MiniPick.get_picker_opts().mappings
		return { move_down = mappings.move_down, move_up = mappings.move_up, choose = mappings.choose, stop = mappings.stop }
	end)()]])
	eq(mappings.move_down, "j")
	eq(mappings.move_up, "k")
	eq(mappings.choose, "<CR>")
	eq(mappings.stop, "<Esc>")
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
	eq(child.api.nvim_buf_get_lines(buf, 0, -1, false)[1], "formatted one")
	child.type_keys("<Down>")
	eq(child.wait([[Previewed == "two"]]), true)
	child.type_keys("<Esc>")
end

return T
