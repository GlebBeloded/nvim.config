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

---@param id string
---@return string
local function configured_lhs(id)
	return child.lua_get(('require("gleb.actions").state.store.last_good[%q][1]'):format(id))
end

--- Press `key` in the conflict and return the working-file lines once the
--- markers are gone (or after the timeout).
---@param key string
---@return string[]
local function choose(key)
	open_conflict_view()
	child.api.nvim_input((key:gsub("<leader>", child.g.mapleader)))
	child.wait(NO_CONFLICT_MARKER, ASYNC_MS)
	return working_lines()
end

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

T["git: Diffview conflict choices come from git actions"] = function()
	eq(choose("<leader>co"), { "ours" })
	eq(choose("<leader>ct"), { "theirs" })
	eq(choose("<leader>cb"), { "base" })
	eq(choose("<leader>ca"), { "ours", "base", "theirs" })
	eq(configured_lhs("diffview.choose_ours"), "<leader>co")
	eq(configured_lhs("diffview.choose_theirs"), "<leader>ct")
	eq(configured_lhs("diffview.choose_base"), "<leader>cb")
	eq(configured_lhs("diffview.choose_all"), "<leader>ca")
end

T["git: <leader>co chooses ours"] = function()
	eq(choose("<leader>co"), { "ours" })
	eq(conflict_resolved(), true)
end

T["git: <leader>ct chooses theirs"] = function()
	eq(choose("<leader>ct"), { "theirs" })
	eq(conflict_resolved(), true)
end

T["git: <leader>cb chooses base"] = function()
	eq(choose("<leader>cb"), { "base" })
	eq(conflict_resolved(), true)
end

T["git: <leader>ca chooses all"] = function()
	eq(choose("<leader>ca"), { "ours", "base", "theirs" })
	eq(conflict_resolved(), true)
end

return T
