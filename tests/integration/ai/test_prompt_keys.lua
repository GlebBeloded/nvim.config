local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

---@class test.AiPrompt
---@field name string buffer name tail (99 names every prompt buffer `99-prompt`)
---@field title string
---@field mode string

--- Headless children have no UI, but 99 sizes its prompt float from
--- `nvim_list_uis()[1]`; report the child's grid as the attached UI.
local FAKE_UI_LUA = [[
	vim.api.nvim_list_uis = function()
		return { { width = vim.o.columns, height = vim.o.lines } }
	end
]]

--- Full config on a scratch file (the alpha dashboard is not modifiable; a
--- named file because auto-save writes modified buffers), 99 loaded.
local function start()
	child.start_config()
	child.lua(FAKE_UI_LUA)
	child.cmd("edit " .. vim.fn.tempname() .. ".txt")
	child.wait_very_lazy()
end

local T = H.child_set(child, start)

--- Buffer name, float title and mode of the focused window.
---@return test.AiPrompt
local function focused_prompt()
	return child.lua_get([[{
		name = vim.fs.basename(vim.api.nvim_buf_get_name(0)),
		title = vim.iter(vim.api.nvim_win_get_config(0).title or {}):map(function(c) return c[1] end):join(""),
		mode = vim.api.nvim_get_mode().mode,
	}]])
end

--- Wait until a 99 prompt buffer is focused in insert mode.
local function wait_prompt()
	child.wait([[vim.fs.basename(vim.api.nvim_buf_get_name(0)) == "99-prompt" and vim.api.nvim_get_mode().mode == "i"]])
end

---@param title string
---@return test.AiPrompt
local function expected_prompt(title)
	return { name = "99-prompt", title = (" 99 %s "):format(title), mode = "i" }
end

--- Number of loaded 99 prompt buffers.
---@return integer
local function prompt_buffers()
	return child.lua_get([[#vim.iter(vim.api.nvim_list_bufs()):filter(function(b)
		return vim.api.nvim_buf_is_loaded(b) and vim.fs.basename(vim.api.nvim_buf_get_name(b)) == "99-prompt"
	end):totable()]])
end

--- Fill the current buffer with lines and select line 2 linewise.
---@return integer buf the buffer holding the selection
local function select_second_line()
	child.api.nvim_buf_set_lines(0, 0, -1, false, { "one", "two", "three" })
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.type_keys("V")
	return child.api.nvim_get_current_buf()
end

--- Lines of the visual selection marks in `buf`.
---@param buf integer
---@return integer[]
local function selection_lines(buf)
	return { child.api.nvim_buf_get_mark(buf, "<")[1], child.api.nvim_buf_get_mark(buf, ">")[1] }
end

---@param lhs string
---@param mode string
---@param callback "vibe_prompt"|"visual_prompt"
local function mapping_uses(lhs, mode, callback)
	eq(
		child.lua_get(([[
		vim.fn.maparg(%q, %q, false, true).callback
			== require("gleb.ai.entry_keymaps")[%q]
	]]):format(lhs, mode, callback)),
		true
	)
end

T["ai: Menu shows prompt"] = function()
	eq(child.fn.maparg("<A-9>", "n"), "")
	eq(prompt_buffers(), 0)
end

---@param id string
---@param title string
local function run_action(id, title)
	child.lua(([[
		local action = require("gleb.actions").state.applicator.catalog:get(%q)
		assert(action, "action is not registered")
		assert(action.title == %q, "action has the wrong title")
		vim.schedule(function()
			action.run(require("gleb.actions.context").capture())
		end)
	]]):format(id, title))
end

T["ai: Menu s opens search prompt"] = function()
	run_action("ai.search", "99 Search")
	wait_prompt()

	eq(focused_prompt(), expected_prompt("Search"))
end

T["ai: Menu v opens vibe prompt"] = function()
	run_action("ai.vibe", "99 Vibe")
	wait_prompt()

	eq(focused_prompt(), expected_prompt("Vibe"))
end

--- Wait until typed keys and the callbacks they scheduled have run.
local function wait_keys_done()
	child.type_keys(":lua vim.schedule(function() vim.g.keys_done = true end)<CR>")
	child.wait("vim.g.keys_done")
end

T["ai: Menu ignores other keys"] = function()
	child.type_keys("<A-9>", "x")
	wait_keys_done()

	eq({ prompt_buffers(), child.api.nvim_get_mode().mode }, { 0, "n" })
	eq(child.fn.maparg("<A-9>", "n"), "")
end

T["ai: Shift-Enter opens vibe prompt"] = function()
	mapping_uses("<S-CR>", "n", "vibe_prompt")
	eq(
		child.lua_get([[
		require("gleb.actions").state.applicator.catalog:get("ai.vibe").run
			== require("gleb.ai.entry_keymaps").vibe_prompt
	]]),
		true
	)
	child.type_keys("<S-CR>")
	wait_prompt()

	eq(focused_prompt(), expected_prompt("Vibe"))
end

T["ai: Visual Alt-9 opens visual prompt"] = function()
	mapping_uses("<A-9>", "x", "visual_prompt")
	local buf = select_second_line()
	child.type_keys("<A-9>")
	wait_prompt()

	eq(focused_prompt(), expected_prompt("Visual"))
	eq(selection_lines(buf), { 2, 2 })
end

T["ai: Visual Shift-Enter opens visual prompt"] = function()
	mapping_uses("<S-CR>", "x", "visual_prompt")
	local buf = select_second_line()
	child.type_keys("<S-CR>")
	wait_prompt()

	eq(focused_prompt(), expected_prompt("Visual"))
	eq(selection_lines(buf), { 2, 2 })
end

return T
