local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

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

return T
