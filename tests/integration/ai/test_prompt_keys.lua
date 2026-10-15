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
	assert(child.wait([[package.loaded["gleb.ai"] ~= nil]]), "99 setup did not finish")
	child.lua([[vim.schedule(function() vim.g.ai_very_lazy_done = true end)]])
	assert(child.wait([[vim.g.ai_very_lazy_done]]), "VeryLazy callbacks did not finish")
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
	assert(
		child.wait(
			[[vim.fs.basename(vim.api.nvim_buf_get_name(0)) == "99-prompt" and vim.api.nvim_get_mode().mode == "i"]]
		),
		"99 prompt did not enter insert mode"
	)
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

T["ai: 99 entry mappings come from AI actions"] = function()
	eq(
		child.lua_get([[(function()
			local actions = require("gleb.actions").state.applicator.catalog
			local expected = {
				{ id = "ai.vibe", lhs = "<S-CR>", mode = "n", desc = "99: Vibe" },
				{ id = "ai.visual", lhs = "<A-9>", mode = "x", desc = "99: Visual" },
				{ id = "ai.visual", lhs = "<S-CR>", mode = "x", desc = "99: Visual" },
			}
			local result = {}
			for _, item in ipairs(expected) do
				local action = actions:get(item.id)
				local map = vim.fn.maparg(item.lhs, item.mode, false, true)
				table.insert(result, {
					id = item.id,
					desc = map.desc,
					silent = map.silent == 1,
					uses_action_mapping = map.callback == action.mapping,
					mapping_runs_action = action.mapping == action.run,
				})
			end
			return result
		end)()]]),
		{
			{
				id = "ai.vibe",
				desc = "99: Vibe",
				silent = true,
				uses_action_mapping = true,
				mapping_runs_action = true,
			},
			{
				id = "ai.visual",
				desc = "99: Visual",
				silent = true,
				uses_action_mapping = true,
				mapping_runs_action = true,
			},
			{
				id = "ai.visual",
				desc = "99: Visual",
				silent = true,
				uses_action_mapping = true,
				mapping_runs_action = true,
			},
		}
	)
end

T["ai: Prompt submit comes from a filetype action"] = function()
	child.type_keys("<S-CR>")
	wait_prompt()

	eq(
		child.lua_get([[(function()
			local buf = vim.iter(vim.api.nvim_list_bufs()):find(function(candidate)
				return vim.api.nvim_buf_is_loaded(candidate)
					and vim.fs.basename(vim.api.nvim_buf_get_name(candidate)) == "99-prompt"
			end)
			local result = {}
			for _, mode in ipairs({ "n", "i" }) do
				local map = vim.iter(vim.api.nvim_buf_get_keymap(buf, mode)):find(function(item)
					return item.lhs == "<S-CR>"
				end)
				table.insert(result, {
					buffer = map ~= nil,
					desc = map and map.desc,
					silent = map and map.silent == 1,
				})
			end
			return result
		end)()]]),
		{
			{ buffer = true, desc = "99: Submit prompt", silent = true },
			{ buffer = true, desc = "99: Submit prompt", silent = true },
		}
	)

	child.lua([[
		require("99.window").clear_active_popups()
		vim.cmd.enew()
		vim.api.nvim_buf_set_name(0, vim.fn.tempname() .. ".prompt")
		vim.bo.buftype = "acwrite"
		vim.api.nvim_create_autocmd("BufWriteCmd", {
			buffer = 0,
			callback = function() vim.g.ai_submit_count = (vim.g.ai_submit_count or 0) + 1 end,
		})
		vim.bo.filetype = "99"
	]])
	child.type_keys("<S-CR>i<S-CR>")
	eq(child.lua_get([[vim.g.ai_submit_count]]), 2)
end

T["ai: 99 hardcoded mappings are the only exceptions"] = function()
	child.type_keys("<S-CR>")
	wait_prompt()
	assert(
		child.wait([[(function()
			local buf = vim.iter(vim.api.nvim_list_bufs()):find(function(candidate)
				return vim.api.nvim_buf_is_loaded(candidate)
					and vim.fs.basename(vim.api.nvim_buf_get_name(candidate)) == "99-prompt"
			end)
			if not buf then
				return false
			end
			local maps = vim.api.nvim_buf_get_keymap(buf, "i")
			return vim.iter(maps):any(function(map) return map.lhs == '"' end)
				and vim.iter(maps):any(function(map) return map.lhs == "<C-Space>" end)
		end)()]]),
		"99 prompt and completion mappings did not settle"
	)
	child.lua([[
		local prompt_buf = vim.iter(vim.api.nvim_list_bufs()):find(function(candidate)
			return vim.api.nvim_buf_is_loaded(candidate)
				and vim.fs.basename(vim.api.nvim_buf_get_name(candidate)) == "99-prompt"
		end)
		local baseline_maps = {}
		for _, mode in ipairs({ "n", "x", "s", "o", "i", "c", "t" }) do
			for _, map in ipairs(vim.api.nvim_buf_get_keymap(prompt_buf, mode)) do
				local key = mode .. ":" .. map.lhs
				if key ~= "n:q" then
					baseline_maps[key] = true
				end
			end
		end
		vim.g.ai_baseline_maps = baseline_maps

		local nn = require("99")
		require("99.window").clear_active_popups()
		local state = nn.__get_state()
		local prompt = require("99.prompt").deserialize(state, {
			user_prompt = "find the definition",
			data = { type = "search", qfix_items = {}, response = "done" },
		})
		state.tracking:track(prompt)
		nn.open()
	]])
	child.wait([[vim.fs.basename(vim.api.nvim_buf_get_name(0)) == "99-prompt"]])

	eq(
		child.lua_get([[(function()
			local exceptions = {}
			for _, mode in ipairs({ "n", "x", "s", "o", "i", "c", "t" }) do
				for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
					local key = mode .. ":" .. map.lhs
					if not vim.g.ai_baseline_maps[key] and map.desc ~= "99: Submit prompt" then
						table.insert(exceptions, key)
					end
				end
			end
			table.sort(exceptions)
			return exceptions
		end)()]]),
		{ "n:<CR>", "n:q" }
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
	eq(
		child.lua_get([[(function()
			local matches = require("gleb.find_action.items").match(
				require("gleb.actions").state.applicator.catalog.actions,
				"99 vibe"
			)
			return vim.tbl_map(function(action) return action.id end, matches)
		end)()]]),
		{ "ai.vibe" }
	)
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
