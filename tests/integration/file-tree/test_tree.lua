local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

-- generous: async results land after >3 s under the 12-worker `make check` load
local ASYNC_MS = 10000

--- Temp git repo with one committed file that has an unstaged change.
---@return string dir
local function modified_repo()
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	local file = vim.fs.joinpath(dir, "a.txt")
	vim.fn.writefile({ "one" }, file)
	vim.system({ "git", "init", "-q" }, { cwd = dir }):wait()
	vim.system({ "git", "add", "a.txt" }, { cwd = dir }):wait()
	vim.system({ "git", "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "init" }, { cwd = dir }):wait()
	vim.fn.writefile({ "two" }, file)
	return dir
end

---@return boolean
local function current_tab_has_neo_tree()
	return child.lua_get([[vim.iter(vim.api.nvim_tabpage_list_wins(0)):any(function(win)
		return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree"
	end)]])
end

--- Stage `a.txt` in `dir`, open `git_status` in the child and press `c` with the
--- AI popup stubbed to confirm `message`; notifications land in the child's `Notes`.
---@param dir string repo from `modified_repo()`
---@param message string
local function commit_from_tree(dir, message)
	vim.system({ "git", "add", "a.txt" }, { cwd = dir }):wait()
	vim.system({ "git", "config", "user.name", "t" }, { cwd = dir }):wait()
	vim.system({ "git", "config", "user.email", "t@t" }, { cwd = dir }):wait()
	child.cmd("cd " .. vim.fn.fnameescape(dir) .. " | enew")
	child.lua(
		[[Notes, CommitMessage = {}, ...
local notify = vim.notify
vim.notify = function(msg, level, opts)
	table.insert(Notes, { msg, level })
	return notify(msg, level, opts)
end
require("gleb.git.ai_commit").show_commit_input = function(cb) cb(CommitMessage) end]],
		{ message }
	)
	child.cmd("Neotree git_status")
	eq(child.wait([[vim.bo.filetype == "neo-tree" and vim.fn.search("a.txt", "nw") > 0]], ASYNC_MS), true)
	child.type_keys("c")
end

---@param dir string
---@return string
local function last_subject(dir)
	return vim.trim(vim.system({ "git", "log", "-1", "--format=%s" }, { cwd = dir, text = true }):wait().stdout)
end

---@param prefix string
---@return boolean
local function wait_note(prefix)
	return child.wait(
		string.format("vim.iter(Notes):any(function(n) return vim.startswith(n[1], %q) end)", prefix),
		ASYNC_MS
	)
end

---@param prefix string
---@return table[]
local function notes_with(prefix)
	return vim.tbl_filter(function(note)
		return vim.startswith(note[1], prefix)
	end, child.lua_get("Notes"))
end

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

T["file-tree: Filesystem tree opens on the left at width 35"] = function()
	child.start_config()
	child.cmd("cd " .. H.root .. " | enew | Neotree filesystem")
	eq(child.wait([[vim.bo.filetype == "neo-tree"]], 3000), true)

	local leftmost = child.lua_get([[vim.fn.win_getid(1)]])
	eq(child.lua_get("vim.bo[vim.api.nvim_win_get_buf(...)].filetype", { leftmost }), "neo-tree")
	eq(child.api.nvim_win_get_width(leftmost), 35)
end

T["file-tree: Missing neo-tree is tolerated"] = function()
	child.start_bare()

	eq(child.lua_get([[pcall(require, "gleb.file_tree")]]), true)
end

T["file-tree: q closes preview and tree"] = function()
	child.start_config()
	child.wait_very_lazy()
	-- codediff view.create crashes until fix-diff-preview-codediff-crash; this case asserts tab state only
	child.lua([[require("codediff.ui.view").create = function() vim.cmd("tabnew") end]])
	child.cmd("cd " .. modified_repo() .. " | enew")
	child.lua([[DiffPreview = require("gleb.file_tree.diff_preview")]])
	local original = child.api.nvim_get_current_tabpage()
	child.cmd("Neotree git_status")
	eq(child.wait([[vim.bo.filetype == "neo-tree" and vim.fn.search("a.txt", "nw") > 0]], ASYNC_MS), true)

	child.type_keys("j")
	eq(child.wait("DiffPreview.state.diff_tab ~= nil", ASYNC_MS), true)
	eq(child.wait([[vim.bo.filetype == "neo-tree"]], ASYNC_MS), true)
	local diff_tab = child.lua_get("DiffPreview.state.diff_tab")
	child.type_keys("q")

	eq(child.api.nvim_get_current_tabpage(), original)
	eq(child.api.nvim_tabpage_is_valid(diff_tab), false)
	eq(child.lua_get("DiffPreview.state.current_file"), vim.NIL)
	eq(child.lua_get("DiffPreview.state.original_tab"), vim.NIL)
	eq(current_tab_has_neo_tree(), false)
end

T["file-tree: c reports commit failure"] = function()
	child.start_config()
	child.wait_very_lazy()
	local dir = modified_repo()
	local hook = vim.fs.joinpath(dir, ".git/hooks/pre-commit")
	vim.fn.writefile({ "#!/bin/sh", 'echo "hook says no" >&2', "exit 1" }, hook)
	vim.fn.setfperm(hook, "rwxr-xr-x")
	commit_from_tree(dir, "feat: x")

	eq(wait_note("Commit failed:"), true)
	eq(notes_with("Commit failed:"), { { "Commit failed: hook says no", vim.log.levels.ERROR } })
	eq(notes_with("Committed:"), {})
	eq(last_subject(dir), "init")
end

T["file-tree: c commits confirmed message"] = function()
	child.start_config()
	child.wait_very_lazy()
	local dir = modified_repo()
	commit_from_tree(dir, "feat: x")
	eq(wait_note("Committed:"), true)
	eq(notes_with("Committed:"), { { "Committed: feat: x", vim.log.levels.INFO } })
	eq(last_subject(dir), "feat: x")

	vim.fn.writefile({ "three" }, vim.fs.joinpath(dir, "a.txt"))
	vim.system({ "git", "add", "a.txt" }, { cwd = dir }):wait()
	child.lua([[Notes, CommitMessage = {}, "fix: it's $HOME"]])
	child.type_keys("c")
	eq(wait_note("Committed:"), true)
	eq(last_subject(dir), "fix: it's $HOME")
end

return T
