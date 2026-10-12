local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

--- neo-tree renders and watches files asynchronously.
local ASYNC_MS = 3000

--- Child-side helpers, defined as the global `Tree` after each start.
local TREE_HELPERS_LUA = [[
Tree = {}

--- First `neo-tree` window of the current tab.
function Tree.win()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree" then return win end
	end
end

function Tree.source(win)
	return vim.b[vim.api.nvim_win_get_buf(win)].neo_tree_source
end

function Tree.state(win)
	return require("neo-tree.sources.manager").get_state_for_window(win)
end

--- Path of the node under the cursor of tree window `win`.
function Tree.cursor_path(win)
	local state = Tree.state(win)
	local node = state and state.tree and state.tree:get_node(vim.api.nvim_win_get_cursor(win)[1])
	return node and node.path
end

--- Line and node of `path` in tree window `win` (nil while not rendered).
function Tree.find(win, path)
	local state = Tree.state(win)
	if not (state and state.tree) then return end
	for line = 1, vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win)) do
		local node = state.tree:get_node(line)
		if node and node.path == path then return line, node end
	end
end

--- Move the cursor of `win` to the node of `path`; false while not rendered.
function Tree.focus(win, path)
	local line = Tree.find(win, path)
	if line then vim.api.nvim_win_set_cursor(win, { line, 0 }) end
	return line ~= nil
end

--- git status code neo-tree shows for the node of `path` (nil without node).
function Tree.git_status(win, path)
	local _, node = Tree.find(win, path)
	return node and node.extra and node.extra.git_status
end

--- Non-tree windows of the current tab.
function Tree.editing_wins()
	return vim.tbl_filter(function(win)
		return vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "neo-tree"
	end, vim.api.nvim_tabpage_list_wins(0))
end

--- Whether every name occurs in the tree buffer of `win`.
function Tree.lists(win, names)
	local text = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false), "\n")
	return vim.iter(names):all(function(name) return text:find(name, 1, true) ~= nil end)
end]]

--- Temp directory (symlinks resolved, like neo-tree's paths) holding `files`.
---@param files table<string, string>
---@return string
local function temp_dir(files)
	local dir = vim.fs.normalize(vim.fn.resolve(vim.fn.tempname()))
	vim.fn.mkdir(dir, "p")
	H.write_files(dir, files)
	return dir
end

--- Full config with the `Tree` helpers and `dir` (if given) as the child's cwd.
---@param dir? string
local function start_in(dir)
	child.start_config()
	child.lua(TREE_HELPERS_LUA)
	if dir then
		child.cmd("cd " .. dir)
	end
end

--- Run `cmd` and wait until a tree window shows `source`.
---@param cmd string
---@param source "filesystem"|"git_status"
---@return integer tree window
local function open_tree(cmd, source)
	child.cmd(cmd)
	eq(child.wait(("Tree.win() and Tree.source(Tree.win()) == %q"):format(source), ASYNC_MS), true)
	return child.lua_get("Tree.win()")
end

--- Wait until the cursor of tree window `win` is on the node for `path`.
---@param win integer
---@param path string
local function wait_cursor_on(win, path)
	eq(child.wait(("Tree.cursor_path(%d) == %q"):format(win, path), ASYNC_MS), true)
end

--- Filesystem tree of `dir` with the cursor on the node for `path`
--- (`reveal_file` moves it there).
---@param dir string
---@param path string
---@return integer tree window
local function open_tree_on(dir, path)
	local win = open_tree("Neotree filesystem reveal_file=" .. vim.fn.fnameescape(path), "filesystem")
	wait_cursor_on(win, path)
	eq(child.lua_get("Tree.state(...).path", { win }), dir)
	return win
end

--- Press `key` in the tree, wait for neo-tree's input popup, type `keys`.
---@param key string
---@param keys string[]
local function answer_prompt(key, keys)
	child.type_keys(key)
	eq(child.wait([[vim.bo.buftype == "prompt" and vim.fn.mode() == "i"]], ASYNC_MS), true)
	child.type_keys(unpack(keys))
end

--- Temp repo with `a.txt` committed then modified (staged too if `staged`),
--- the child in it and the `git_status` tree's cursor on `a.txt`.
---@param staged boolean
---@return string repo, integer win, string path
local function git_status_on_changed_file(staged)
	local repo = H.git_repo({ ["a.txt"] = "a\n" })
	H.write_files(repo, { ["a.txt"] = "changed\n" })
	if staged then
		H.git(repo, { "add", "a.txt" })
	end
	start_in(repo)
	child.cmd("enew")
	local win = open_tree("Neotree git_status", "git_status")
	local path = vim.fs.joinpath(repo, "a.txt")
	eq(child.wait(("Tree.focus(%d, %q)"):format(win, path), ASYNC_MS), true)
	return repo, win, path
end

---@param repo string
---@return string[] paths in `git diff --cached --name-only`
local function staged_paths(repo)
	return vim.split(vim.trim(H.git(repo, { "diff", "--cached", "--name-only" })), "\n", { trimempty = true })
end

--- Wait until the staged paths of `repo` equal `expected`.
---@param repo string
---@param expected string[]
local function wait_staged(repo, expected)
	vim.wait(ASYNC_MS, function()
		return vim.deep_equal(staged_paths(repo), expected)
	end, 20)
	eq(staged_paths(repo), expected)
end

---@param path string
---@return boolean
local function exists(path)
	return vim.uv.fs_stat(path) ~= nil
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

T["file-tree: Git status tree opens on the left at width 35"] = function()
	local repo = H.git_repo({ ["a.txt"] = "a\n" })
	H.write_files(repo, { ["a.txt"] = "changed\n" })
	start_in(repo)
	child.cmd("enew")

	local win = open_tree("Neotree git_status", "git_status")

	eq(child.lua_get("vim.fn.win_getid(1)"), win)
	eq(child.api.nvim_win_get_width(win), 35)
end

T["file-tree: Tree closes with last window"] = function()
	start_in(temp_dir({ ["a.txt"] = "a\n" }))
	child.cmd("edit a.txt")
	open_tree("Neotree filesystem", "filesystem")
	child.cmd("wincmd l")
	eq(child.bo.filetype, "text")

	local job = child.job.id
	child.api_notify.nvim_command("q")
	eq(vim.fn.jobwait({ job }, 5000)[1], 0)
end

T["file-tree: Directory argument opens tree in current window"] = function()
	local dir = temp_dir({ ["a.txt"] = "a\n" })
	start_in()
	local win = child.api.nvim_get_current_win()

	child.cmd("edit " .. dir)

	eq(child.wait([[vim.bo.filetype == "neo-tree"]], ASYNC_MS), true)
	eq(child.api.nvim_get_current_win(), win)
	eq(child.lua_get("Tree.state(...).path", { win }), dir)
end

T["file-tree: Current file is followed"] = function()
	local dir = temp_dir({ ["a.txt"] = "a\n", ["b.txt"] = "b\n" })
	start_in(dir)
	child.cmd("edit a.txt")
	local win = open_tree("Neotree filesystem", "filesystem")
	child.cmd("wincmd l")

	child.cmd("edit b.txt")

	local b = vim.fs.joinpath(dir, "b.txt")
	eq(child.wait(("Tree.cursor_path(%d) == %q"):format(win, b), ASYNC_MS), true)
end

T["file-tree: Dotfiles and gitignored files are listed"] = function()
	local repo = H.git_repo({ [".gitignore"] = "ignored.txt\n", ["a.txt"] = "a\n" })
	H.write_files(repo, { [".hidden"] = "", ["ignored.txt"] = "" })
	start_in(repo)

	local win = open_tree("Neotree filesystem", "filesystem")

	eq(child.wait(("Tree.lists(%d, { '.hidden', 'ignored.txt' })"):format(win), ASYNC_MS), true)
end

T["file-tree: Next source switches tree source"] = function()
	start_in(H.git_repo({ ["a.txt"] = "a\n" }))
	local win = open_tree("Neotree filesystem", "filesystem")

	child.type_keys(">")

	eq(child.wait(("Tree.source(%d) == 'git_status'"):format(win), ASYNC_MS), true)
end

T["file-tree: v opens file in vertical split"] = function()
	local dir = temp_dir({ ["a.txt"] = "a\n", ["b.txt"] = "b\n" })
	start_in(dir)
	child.cmd("edit a.txt")
	local previous = child.api.nvim_get_current_win()
	local b = vim.fs.joinpath(dir, "b.txt")
	open_tree_on(dir, b)

	child.type_keys("v")

	eq(child.wait(("vim.api.nvim_buf_get_name(0) == %q"):format(b), ASYNC_MS), true)
	local split = child.api.nvim_get_current_win()
	local editing = child.lua_get("Tree.editing_wins()")
	table.sort(editing)
	eq(editing, { previous, split })
	eq(child.api.nvim_buf_get_name(child.api.nvim_win_get_buf(previous)), vim.fs.joinpath(dir, "a.txt"))
	-- side by side: same top row and height, different columns
	local split_pos, previous_pos = child.fn.win_screenpos(split), child.fn.win_screenpos(previous)
	eq(split_pos[1], previous_pos[1])
	eq(child.api.nvim_win_get_height(split), child.api.nvim_win_get_height(previous))
	eq(split_pos[2] ~= previous_pos[2], true)
end

T["file-tree: t opens file in new tab"] = function()
	local dir = temp_dir({ ["a.txt"] = "a\n", ["b.txt"] = "b\n" })
	start_in(dir)
	child.cmd("edit a.txt")
	local b = vim.fs.joinpath(dir, "b.txt")
	open_tree_on(dir, b)
	local tabs = #child.api.nvim_list_tabpages()

	child.type_keys("t")

	eq(child.wait(("#vim.api.nvim_list_tabpages() == %d"):format(tabs + 1), ASYNC_MS), true)
	eq(child.api.nvim_buf_get_name(0), b)
end

T["file-tree: a creates a file"] = function()
	local dir = temp_dir({ ["a.txt"] = "a\n" })
	start_in(dir)
	local win = open_tree("Neotree filesystem", "filesystem")
	wait_cursor_on(win, dir)

	answer_prompt("a", { "new.txt<CR>" })

	local new = vim.fs.joinpath(dir, "new.txt")
	eq(
		vim.wait(ASYNC_MS, function()
			return exists(new)
		end, 20),
		true
	)
	eq(child.wait(("Tree.lists(%d, { 'new.txt' })"):format(win), ASYNC_MS), true)
end

T["file-tree: r renames a file"] = function()
	local dir = temp_dir({ ["old.txt"] = "old\n" })
	start_in(dir)
	local old = vim.fs.joinpath(dir, "old.txt")
	open_tree_on(dir, old)

	answer_prompt("r", { "<C-u>", "renamed.txt<CR>" })

	eq(
		vim.wait(ASYNC_MS, function()
			return exists(vim.fs.joinpath(dir, "renamed.txt"))
		end, 20),
		true
	)
	eq(exists(old), false)
end

T["file-tree: Space stages an unstaged file"] = function()
	local repo, win, path = git_status_on_changed_file(false)
	eq(staged_paths(repo), {})
	local before = child.lua_get("Tree.git_status(...)", { win, path })

	child.type_keys("<Space>")

	wait_staged(repo, { "a.txt" })
	-- refreshed: the node shows the new (staged) status
	eq(child.wait(("Tree.git_status(%d, %q) ~= %q"):format(win, path, before), ASYNC_MS), true)
end

T["file-tree: Space unstages a staged file"] = function()
	local repo = git_status_on_changed_file(true)
	eq(staged_paths(repo), { "a.txt" })

	child.type_keys("<Space>")

	wait_staged(repo, {})
end

local INFO, ERROR = vim.log.levels.INFO, vim.log.levels.ERROR

--- Wait until `count` notifications are recorded, then return them.
---@param notifications fun(): test.Notification[]
---@param count integer
---@return test.Notification[]
local function wait_notifications(notifications, count)
	vim.wait(ASYNC_MS, function()
		return #notifications() >= count
	end, 20)
	return notifications()
end

--- Press `P` in the git_status tree with `git push` scripted to exit `code`.
---@param code integer
---@return test.JobCall[] calls, test.Notification[] notifications
local function push_exiting(code)
	git_status_on_changed_file(false)
	local calls = H.record_jobstart(child, { git = { code = code } })
	local notifications = H.record_notify(child)

	child.type_keys("P")

	return calls(), wait_notifications(notifications, 2)
end

T["file-tree: c commits confirmed message"] = function()
	local repo = git_status_on_changed_file(true)
	local calls = H.record_jobstart(child, { ollama = { stdout = { "feat: x", "" } } })
	local notifications = H.record_notify(child)

	child.type_keys("c")
	eq(child.wait([[vim.bo.filetype == "gitcommit" and vim.api.nvim_get_current_line() == "feat: x"]], ASYNC_MS), true)
	eq(calls()[1].cmd[1], "ollama")
	child.type_keys("<CR>")

	eq(wait_notifications(notifications, 1), { { msg = "Committed: feat: x", level = INFO } })
	eq(vim.trim(H.git(repo, { "log", "-1", "--format=%s" })), "feat: x")
end

T["file-tree: P pushes successfully"] = function()
	local calls, notifications = push_exiting(0)

	eq(calls, { { cmd = "git push", stdin = "", stopped = false } })
	eq(notifications, {
		{ msg = "Pushing...", level = INFO },
		{ msg = "Pushed successfully", level = INFO },
	})
end

T["file-tree: P reports push failure"] = function()
	local calls, notifications = push_exiting(1)

	eq(calls, { { cmd = "git push", stdin = "", stopped = false } })
	eq(notifications, {
		{ msg = "Pushing...", level = INFO },
		{ msg = "Push failed", level = ERROR },
	})
end

T["file-tree: Missing neo-tree is tolerated"] = function()
	child.start_bare()

	eq(child.lua_get([[pcall(require, "gleb.file_tree")]]), true)
end

return T
