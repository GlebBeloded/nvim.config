local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local ASYNC_MS = 10000
--- Lua expression: the current buffer holds no diff3 conflict marker line.
local NO_CONFLICT_MARKER = [[not vim.iter(vim.api.nvim_buf_get_lines(0, 0, -1, false)):any(function(line)
	return line:match("^<<<<<<<") or line:match("^|||||||") or line:match("^=======") or line:match("^>>>>>>>")
end)]]

---@param dir string
---@param args string[]
local function git(dir, args)
	local cmd = { "git", "-c", "user.name=t", "-c", "user.email=t@t", "-c", "merge.conflictStyle=diff3" }
	vim.system(vim.list_extend(cmd, args), { cwd = dir }):wait()
end

---@param dir string
---@param line string
---@param message string
local function commit_line(dir, line, message)
	vim.fn.writefile({ line }, vim.fs.joinpath(dir, "a.txt"))
	git(dir, { "add", "a.txt" })
	git(dir, { "commit", "-qm", message })
end

--- Temp git repo mid-merge: `a.txt` holds a diff3 conflict with ours `ours`,
--- base `base` and theirs `theirs`.
---@return string dir
local function conflicted_repo()
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	git(dir, { "init", "-q", "-b", "main" })
	commit_line(dir, "base", "base")
	git(dir, { "checkout", "-qb", "theirs" })
	commit_line(dir, "theirs", "theirs")
	git(dir, { "checkout", "-q", "main" })
	commit_line(dir, "ours", "ours")
	git(dir, { "merge", "-q", "theirs" })
	return dir
end

--- Temp git repo with unstaged changes to two files, `a.txt` and `b.txt`.
---@return string dir
local function two_changed_files_repo()
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	git(dir, { "init", "-q", "-b", "main" })
	for _, name in ipairs({ "a.txt", "b.txt" }) do
		vim.fn.writefile({ "old" }, vim.fs.joinpath(dir, name))
	end
	git(dir, { "add", "." })
	git(dir, { "commit", "-qm", "init" })
	for _, name in ipairs({ "a.txt", "b.txt" }) do
		vim.fn.writefile({ "new" }, vim.fs.joinpath(dir, name))
	end
	return dir
end

--- Lua expression: the current window is a diff window on the working file `name`.
---@param name string
---@return string
local function working_diff_window(name)
	return ([[vim.wo.diff and vim.bo.buftype == "" and vim.api.nvim_buf_get_name(0):match("^/.*/%s$") ~= nil]]):format(
		vim.pesc(name)
	)
end

--- Lua: focus the diff window on the working file named by the first argument;
--- returns whether one exists.
local FOCUS_WORKING_DIFF_WINDOW = [[local name = ...
for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
	local buf = vim.api.nvim_win_get_buf(win)
	if vim.wo[win].diff and vim.api.nvim_buf_get_name(buf):match("^/.*/" .. vim.pesc(name) .. "$") then
		vim.api.nvim_set_current_win(win)
		return true
	end
end
return false]]

--- Open diffview on a conflicted repo and wait until the working-file diff
--- window is current, with the cursor on the conflict's first marker.
local function open_conflict_view()
	child.start_config()
	child.cmd("cd " .. conflicted_repo())
	child.cmd("DiffviewOpen")
	assert(
		child.wait(
			[[vim.wo.diff and vim.bo.buftype == "" and vim.api.nvim_buf_get_name(0):match("/a%.txt$")]],
			ASYNC_MS
		),
		"diffview did not show the working file"
	)
	child.cmd("call search('^<<<<<<<', 'cw')")
end

---@return string[]
local function working_lines()
	return child.api.nvim_buf_get_lines(0, 0, -1, false)
end

---@return boolean
local function conflict_resolved()
	return child.lua_get(NO_CONFLICT_MARKER)
end

--- Press `key` in the conflict and return the working-file lines once the
--- markers are gone (or after the timeout).
---@param key string
---@return string[]
local function choose(key)
	open_conflict_view()
	child.api.nvim_input(key)
	child.wait(NO_CONFLICT_MARKER, ASYNC_MS)
	return working_lines()
end

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

T["git: tab moves to next entry"] = function()
	child.start_config()
	child.cmd("cd " .. two_changed_files_repo())
	child.cmd("DiffviewOpen")
	local focused = vim.wait(ASYNC_MS, function()
		return child.lua(FOCUS_WORKING_DIFF_WINDOW, { "a.txt" })
	end, 20)
	assert(focused, "diffview did not show a.txt")
	child.api.nvim_input("<tab>")
	eq(child.wait(working_diff_window("b.txt"), ASYNC_MS), true)
end

T["git: dx drops both conflict sides"] = function()
	local lines = choose("dx")
	eq(conflict_resolved(), true)
	eq(vim.tbl_contains(lines, "ours") or vim.tbl_contains(lines, "theirs"), false, lines)
end

T["git: Cmd+O chooses ours"] = function()
	eq(choose("<D-o>"), { "ours" })
	eq(conflict_resolved(), true)
end

T["git: Cmd+I chooses theirs"] = function()
	eq(choose("<D-i>"), { "theirs" })
	eq(conflict_resolved(), true)
end

T["git: Cmd+D chooses base"] = function()
	eq(choose("<D-d>"), { "base" })
	eq(conflict_resolved(), true)
end

T["git: Cmd+A chooses all"] = function()
	eq(choose("<D-a>"), { "ours", "base", "theirs" })
	eq(conflict_resolved(), true)
end

return T
