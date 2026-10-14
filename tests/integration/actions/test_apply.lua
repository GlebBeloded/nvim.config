local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_config()
	child.lua([[
		Actions = require("gleb.actions")
		ShortcutPath = vim.fn.tempname()
		FixtureActions = {
			{
				id = "edit.global_action",
				title = "Global Action",
				category = "Edit",
				modes = { "n", "x" },
				run = function() end,
			},
			{
				id = "git.file_action",
				title = "File Action",
				category = "Git | Diff",
				ft = "action_fixture",
				run = function() end,
			},
		}
		Actions.setup({ FixtureActions }, ShortcutPath)
	]])
end

local T = H.child_set(child, start)

---@param shortcuts table<string, string[]>
local function write_shortcuts(shortcuts)
	child.lua(
		[[local path, value = ...; vim.fn.writefile({ vim.json.encode(value) }, path)]],
		{ child.lua_get([[ShortcutPath]]), shortcuts }
	)
end

---@param lhs string
---@param mode? string
---@return string|false
local function global_desc(lhs, mode)
	return child.lua_get(
		[[(function(lhs, mode) local map = vim.fn.maparg(lhs, mode, false, true); return map.buffer == 0 and map.desc or false end)(...)]],
		{ lhs, mode or "n" }
	)
end

---@param buf integer
---@param lhs string
---@param mode? string
---@return string|false
local function local_desc(buf, lhs, mode)
	return child.lua_get(
		[[(function(buf, lhs, mode)
		for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
			if map.lhs == lhs then return map.desc end
		end
		return false
	end)(...)]],
		{ buf, lhs, mode or "n" }
	)
end

T["actions: Global bindings exist after VeryLazy"] = function()
	write_shortcuts({ ["edit.global_action"] = { "<F20>" } })
	child.wait_very_lazy()

	eq(global_desc("<F20>", "n"), "Edit: Global Action")
	eq(global_desc("<F20>", "x"), "Edit: Global Action")
end

T["actions: Filetype bindings are buffer-local"] = function()
	write_shortcuts({ ["git.file_action"] = { "gx" } })
	child.wait_very_lazy()
	child.lua([[
		MatchingBuffer = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_set_current_buf(MatchingBuffer)
		vim.cmd("setfiletype action_fixture")
		OtherBuffer = vim.api.nvim_create_buf(true, false)
	]])

	local matching = child.lua_get([[MatchingBuffer]])
	local other = child.lua_get([[OtherBuffer]])
	eq(local_desc(matching, "gx"), "Git | Diff: File Action")
	eq(local_desc(other, "gx"), false)
	eq(global_desc("gx"), false)
end

T["actions: Reapplying removes stale bindings"] = function()
	write_shortcuts({
		["edit.global_action"] = { "<F20>" },
		["git.file_action"] = { "gx" },
	})
	child.wait_very_lazy()
	child.lua([[
		MatchingBuffer = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_set_current_buf(MatchingBuffer)
		vim.cmd("setfiletype action_fixture")
	]])

	write_shortcuts({
		["edit.global_action"] = { "<F21>" },
		["git.file_action"] = { "gy" },
	})
	child.lua([[Actions.apply()]])

	local matching = child.lua_get([[MatchingBuffer]])
	eq(global_desc("<F20>"), false)
	eq(global_desc("<F21>"), "Edit: Global Action")
	eq(local_desc(matching, "gx"), false)
	eq(local_desc(matching, "gy"), "Git | Diff: File Action")
end

T["actions: Failed reload keeps applied bindings"] = function()
	write_shortcuts({
		["edit.global_action"] = { "<F20>" },
		["git.file_action"] = { "gx" },
	})
	child.wait_very_lazy()
	child.lua([[
		MatchingBuffer = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_set_current_buf(MatchingBuffer)
		vim.cmd("setfiletype action_fixture")
		vim.fn.writefile({ "not json" }, ShortcutPath)
		ReloadOk = Actions.apply()
	]])

	local matching = child.lua_get([[MatchingBuffer]])
	eq(child.lua_get([[ReloadOk]]), false)
	eq(global_desc("<F20>"), "Edit: Global Action")
	eq(local_desc(matching, "gx"), "Git | Diff: File Action")
end

return T
