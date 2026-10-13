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

---@param dir string
---@param args string[]
---@return string stdout
local function git(dir, args)
	return vim.system(vim.list_extend({ "git" }, args), { cwd = dir, text = true }):wait().stdout
end

--- Open the git_status tree on `dir` with the cursor on `a.txt`.
---@param dir string
local function open_git_status(dir)
	child.start_config()
	child.wait_very_lazy()
	child.cmd("cd " .. dir .. " | enew | Neotree git_status")
	eq(child.wait([[vim.bo.filetype == "neo-tree" and vim.fn.search("a.txt", "nw") > 0]], ASYNC_MS), true)
	child.lua([[vim.fn.search("a.txt")]])
end

--- Press X on the cursor node and answer the neo-tree confirm popup.
---@param answer "y"|"n"
local function revert_with_answer(answer)
	child.type_keys("X")
	eq(child.wait([[vim.fn.getline("."):find(" y/n: ", 1, true) ~= nil]], ASYNC_MS), true)
	child.type_keys(answer, "<CR>")
end

--- Record the child's notifications as `{ msg, level }` in its global `Notes`.
local function record_notes()
	child.lua([[Notes = {}
local notify = vim.notify
vim.notify = function(msg, level, opts)
	table.insert(Notes, { msg, level })
	return notify(msg, level, opts)
end]])
end

--- Give `dir` a bare `origin` remote that tracks its current branch.
---@param dir string
local function add_upstream(dir)
	local remote = vim.fn.tempname()
	vim.system({ "git", "init", "-q", "--bare", remote }):wait()
	git(dir, { "remote", "add", "origin", remote })
	git(dir, { "push", "-q", "-u", "origin", "HEAD" })
end

--- Stage `a.txt` in `dir`, open `git_status` in the child and press `gc` with the
--- AI popup stubbed to confirm `message`; notifications land in the child's `Notes`.
---@param dir string repo from `modified_repo()`
---@param message string
local function commit_from_tree(dir, message)
	vim.system({ "git", "add", "a.txt" }, { cwd = dir }):wait()
	vim.system({ "git", "config", "user.name", "t" }, { cwd = dir }):wait()
	vim.system({ "git", "config", "user.email", "t@t" }, { cwd = dir }):wait()
	child.cmd("cd " .. vim.fn.fnameescape(dir) .. " | enew")
	record_notes()
	child.lua(
		[[CommitMessage = ...
require("gleb.git.ai_commit").show_commit_input = function(cb) cb(CommitMessage) end]],
		{ message }
	)
	child.cmd("Neotree git_status")
	eq(child.wait([[vim.bo.filetype == "neo-tree" and vim.fn.search("a.txt", "nw") > 0]], ASYNC_MS), true)
	child.type_keys("gc")
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

--- Open `git_status` on `dir`, record notes, press `P` and wait for the push result.
---@param dir string
---@param result_prefix string
local function push_from_tree(dir, result_prefix)
	open_git_status(dir)
	record_notes()
	child.type_keys("P")
	eq(wait_note(result_prefix), true)
end

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

T["file-tree: gc reports commit failure"] = function()
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

T["file-tree: gc commits confirmed message"] = function()
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
	child.type_keys("gc")
	eq(wait_note("Committed:"), true)
	eq(last_subject(dir), "fix: it's $HOME")
end

T["file-tree: X reverts a file after confirmation"] = function()
	local dir = modified_repo()
	open_git_status(dir)

	revert_with_answer("y")

	eq(
		vim.wait(ASYNC_MS, function()
			return git(dir, { "status", "--porcelain" }) == ""
		end, 20),
		true
	)
	eq(vim.fn.readfile(vim.fs.joinpath(dir, "a.txt")), { "one" })
end

T["file-tree: X keeps a file when revert is declined"] = function()
	local dir = modified_repo()
	open_git_status(dir)

	revert_with_answer("n")

	eq(child.wait([[vim.bo.filetype == "neo-tree"]], ASYNC_MS), true)
	eq(vim.fn.readfile(vim.fs.joinpath(dir, "a.txt")), { "two" })
	eq(git(dir, { "status", "--porcelain" }), " M a.txt\n")
end

T["file-tree: gr keeps its global meaning in git status tree"] = function()
	open_git_status(modified_repo())

	eq(child.lua_get([[vim.fn.maparg("gr", "n", false, true).buffer]]), 0)
	eq(
		child.lua_get([[vim.fn.maparg("gr", "n", false, true).callback == require("telescope.builtin").lsp_references]]),
		true
	)
end

T["file-tree: c is copy in git status tree"] = function()
	open_git_status(modified_repo())

	local desc = child.lua_get([[vim.iter(vim.api.nvim_buf_get_keymap(0, "n")):find(function(map)
		return map.lhs == "c"
	end).desc]])
	eq(desc, "copy")
end

T["file-tree: Enter opens file and switches to filesystem tree"] = function()
	local dir = modified_repo()
	open_git_status(dir)

	child.type_keys("<CR>")

	eq(child.wait([[vim.fn.expand("%:t") == "a.txt"]], ASYNC_MS), true)
	eq(#child.api.nvim_list_tabpages(), 1)
	eq(child.lua_get([[require("gleb.file_tree.diff_preview").state.diff_tab]]), vim.NIL)
	eq(child.bo.filetype ~= "neo-tree", true)
	eq(
		child.lua_get([[vim.iter(vim.api.nvim_tabpage_list_wins(0)):map(vim.api.nvim_win_get_buf):filter(function(buf)
			return vim.bo[buf].filetype == "neo-tree"
		end):map(function(buf) return vim.b[buf].neo_tree_source end):totable()]]),
		{ "filesystem" }
	)
end

T["file-tree: P pushes successfully"] = function()
	local dir = modified_repo()
	add_upstream(dir)

	push_from_tree(dir, "Pushed")

	eq(child.lua_get("Notes"), {
		{ "Pushing...", vim.log.levels.INFO },
		{ "Pushed successfully", vim.log.levels.INFO },
	})
end

T["file-tree: P reports push failure"] = function()
	push_from_tree(modified_repo(), "Push failed")

	eq(child.lua_get("Notes"), {
		{ "Pushing...", vim.log.levels.INFO },
		{ "Push failed", vim.log.levels.ERROR },
	})
end

return T
