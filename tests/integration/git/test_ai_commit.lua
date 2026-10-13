local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local ASYNC_MS = 3000

--- Temp git repo with one committed file; the child `cd`s into it.
---@param staged boolean change the file and `git add` it
---@return string dir
local function repo(staged)
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	local file = vim.fs.joinpath(dir, "a.txt")
	vim.fn.writefile({ "one" }, file)
	vim.system({ "git", "init", "-q" }, { cwd = dir }):wait()
	vim.system({ "git", "config", "user.name", "t" }, { cwd = dir }):wait()
	vim.system({ "git", "config", "user.email", "t@t" }, { cwd = dir }):wait()
	vim.system({ "git", "add", "a.txt" }, { cwd = dir }):wait()
	vim.system({ "git", "commit", "-qm", "init" }, { cwd = dir }):wait()
	if staged then
		vim.fn.writefile({ "two" }, file)
		vim.system({ "git", "add", "a.txt" }, { cwd = dir }):wait()
	end
	child.cmd("cd " .. vim.fn.fnameescape(dir))
	return dir
end

--- Dir with an executable `ollama` stub driven by FAKE_OLLAMA_* env vars.
---@return string dir
local function fake_ollama()
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	local script = vim.fs.joinpath(dir, "ollama")
	vim.fn.writefile({
		"#!/bin/sh",
		"cat >/dev/null",
		'sleep "${FAKE_OLLAMA_SLEEP:-0}"',
		"printf '%b' \"$FAKE_OLLAMA_OUT\"",
		'exit "${FAKE_OLLAMA_CODE:-0}"',
	}, script)
	vim.fn.setfperm(script, "rwxr-xr-x")
	return dir
end

--- Staged repo plus the `ollama` stub on the child's PATH.
---@param env table<string, string> FAKE_OLLAMA_* values
local function ollama_repo(env)
	repo(true)
	child.lua([[vim.env.PATH = ... .. ":" .. vim.env.PATH]], { fake_ollama() })
	for name, value in pairs(env) do
		child.lua("vim.env[...] = select(2, ...)", { name, value })
	end
end

--- Open the popup; confirmed messages land in the child's `Commits`.
---@return integer winid
local function open_popup()
	child.lua([[Commits = {}
require("gleb.git.ai_commit").show_commit_input(function(t) table.insert(Commits, t) end)]])
	return child.api.nvim_get_current_win()
end

---@param winid integer
---@param lines string[]
local function set_popup_lines(winid, lines)
	child.api.nvim_buf_set_lines(child.api.nvim_win_get_buf(winid), 0, -1, false, lines)
end

---@return string[]
local function popup_lines()
	return child.api.nvim_buf_get_lines(0, 0, -1, false)
end

--- First line of the nui border float (the title row).
---@return string
local function popup_title()
	return child.lua_get([[vim.iter(vim.api.nvim_list_wins())
		:filter(function(win) return win ~= vim.api.nvim_get_current_win() and vim.api.nvim_win_get_config(win).relative ~= "" end)
		:map(function(win) return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, 1, false)[1] end)
		:find(function(line) return line:find("╭", 1, true) ~= nil end) or ""]])
end

---@param title string
---@return boolean
local function wait_title(title)
	return vim.wait(ASYNC_MS, function()
		return popup_title():find(title, 1, true) ~= nil
	end, 20)
end

---@return string[]
local function commits()
	return child.lua_get("Commits")
end

local T = H.child_set(child, function()
	child.start_config()
	child.wait_very_lazy()
end)

T["git: Enter on placeholder does nothing"] = function()
	repo(false)
	for _, lines in ipairs({ { "# No staged changes" }, { "# Error: Ollama exited with code 1" } }) do
		local win = open_popup()
		set_popup_lines(win, lines)
		child.type_keys("<CR>")
		eq(child.api.nvim_win_is_valid(win), true)
		eq(#commits(), 0)
		child.type_keys("q")
	end
end

T["git: Enter drops comment lines"] = function()
	repo(false)
	local win = open_popup()
	set_popup_lines(win, { "feat: x", "# note" })
	child.type_keys("<CR>")
	eq(child.api.nvim_win_is_valid(win), false)
	eq(commits(), { "feat: x" })
end

T["git: Enter confirms message"] = function()
	repo(false)
	local win = open_popup()
	set_popup_lines(win, { "feat: x  " })
	child.type_keys("<CR>")
	eq(child.api.nvim_win_is_valid(win), false)
	eq(commits(), { "feat: x" })
end

T["git: Enter on empty buffer does nothing"] = function()
	repo(false)
	local win = open_popup()
	set_popup_lines(win, { "" })
	child.type_keys("<CR>")
	eq(child.api.nvim_win_is_valid(win), true)
	eq(#commits(), 0)
end

T["git: Empty Ollama output is shown"] = function()
	for _, out in ipairs({ "```\\n```\\n", "  \\n" }) do
		ollama_repo({ FAKE_OLLAMA_OUT = out })
		open_popup()
		eq(wait_title(" Commit Message "), true)
		eq(popup_lines(), { "# Error: Ollama returned an empty message" })
		child.type_keys("q")
	end
end

T["git: q discards popup"] = function()
	ollama_repo({ FAKE_OLLAMA_SLEEP = "1" })
	local win = open_popup()
	child.type_keys("q")
	eq(child.api.nvim_win_is_valid(win), false)
	child.lua("vim.wait(500)")
	eq(#commits(), 0)
	eq(child.v.errmsg, "")
end

T["git: Generated message fills popup"] = function()
	ollama_repo({ FAKE_OLLAMA_OUT = "```\\nfeat(git): add x\\n```\\n" })
	open_popup()
	eq(wait_title(" Commit Message "), true)
	eq(popup_lines(), { "feat(git): add x" })
end

T["git: Popup resizes to content"] = function()
	child.o.columns = 200
	ollama_repo({ FAKE_OLLAMA_OUT = "feat: x\\n" })
	local win = open_popup()
	eq(wait_title(" Commit Message "), true)
	eq(child.api.nvim_win_get_width(win), 72)
	eq(child.api.nvim_win_get_height(win), 1)
end

T["git: Ollama failure is shown"] = function()
	ollama_repo({ FAKE_OLLAMA_CODE = "1" })
	open_popup()
	eq(wait_title(" Commit Message "), true)
	eq(popup_lines(), { "# Error: Ollama exited with code 1" })
end

return T
