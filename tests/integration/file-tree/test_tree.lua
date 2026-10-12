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

T["file-tree: Missing neo-tree is tolerated"] = function()
	child.start_bare()

	eq(child.lua_get([[pcall(require, "gleb.file_tree")]]), true)
end

return T
