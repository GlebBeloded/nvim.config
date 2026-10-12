local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

--- Git-tracked files of this checkout used as diff targets.
local TRACKED = vim.fs.joinpath(H.root, "lua/gleb/file_tree/diff_preview.lua")
local ASYNC_MS = 3000

local function start()
	child.start_config()
	child.wait_very_lazy()
	child.cmd("cd " .. H.root .. " | enew")
	child.lua([[DiffPreview = require("gleb.file_tree.diff_preview")]])
end

--- Committed files of the temp repo; `a/` and `b/` give directory nodes between files.
local REPO_FILES = { ["a/x.lua"] = "x = 1\n", ["b/y.lua"] = "y = 1\n", ["z.lua"] = "z = 1\n" }

---@type string
local repo

--- Temp repo with `a/x.lua`, `b/y.lua` modified and `z.lua` deleted, as the child's cwd.
local function start_repo()
	repo = H.git_repo(REPO_FILES)
	H.write_files(repo, { ["a/x.lua"] = "x = 2\n", ["b/y.lua"] = "y = 2\n" })
	vim.fn.delete(vim.fs.joinpath(repo, "z.lua"))
	child.cmd("cd " .. repo)
	child.lua([[
		---@param path string
		---@return NuiTree.Node?, integer?
		function GitStatusNode(path)
			local tree = require("neo-tree.sources.manager").get_state("git_status").tree
			if tree then
				return tree:get_node(path)
			end
		end

		---@param path string
		---@return boolean
		function DiffTabShows(path)
			local tab = DiffPreview.state.diff_tab
			return tab ~= nil and vim.api.nvim_tabpage_is_valid(tab)
				and vim.iter(vim.api.nvim_tabpage_list_wins(tab)):any(function(win)
					return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)) == path
				end)
		end
	]])
end

---@param rel string path relative to the temp repo
---@return string
local function repo_path(rel)
	return vim.fs.joinpath(repo, rel)
end

--- Open the `git_status` tree and wait until it lists `path`.
---@param path string
local function open_git_status(path)
	child.cmd("Neotree git_status")
	eq(child.wait(("vim.bo.filetype == 'neo-tree' and GitStatusNode(%q) ~= nil"):format(path), ASYNC_MS), true)
end

--- Put the tree cursor on the node of `path`.
---@param path string
local function cursor_on(path)
	child.lua("vim.api.nvim_win_set_cursor(0, { select(2, GitStatusNode(...)), 0 })", { path })
end

---@return string? path of the node under the tree cursor
local function cursor_path()
	return child.lua_get([[require("neo-tree.sources.manager").get_state("git_status").tree:get_node().path]])
end

---@return integer
local function tab_count()
	return #child.api.nvim_list_tabpages()
end

---@param path string
local function open_diff(path)
	child.lua("DiffPreview.open_diff(...)", { path })
end

---@return boolean
local function wait_diff_tab()
	return child.wait("DiffPreview.state.diff_tab ~= nil", ASYNC_MS)
end

--- Lua expression: a window of the diff tab shows the buffer of `path`.
---@param path string
---@return string
local function diff_tab_shows(path)
	return ("DiffTabShows(%q)"):format(path)
end

---@return boolean
local function current_is_neo_tree()
	return child.bo.filetype == "neo-tree"
end

local T = H.child_set(child, start)

T["file-tree: Current file is tracked immediately"] = function()
	open_diff(TRACKED)

	eq(child.lua_get("DiffPreview.state.current_file"), TRACKED)
end

T["file-tree: Original tab is saved"] = function()
	local original = child.api.nvim_get_current_tabpage()
	open_diff(TRACKED)

	eq(child.wait("DiffPreview.state.original_tab ~= nil", ASYNC_MS), true)
	eq(child.lua_get("DiffPreview.state.original_tab"), original)
end

local CODEDIFF_CRASH = "fix-diff-preview-codediff-crash: open_diff crashes in codediff view.create"

T["file-tree: Diff tab is created"] = H.xfail(CODEDIFF_CRASH, function()
	local before = tab_count()
	open_diff(TRACKED)

	eq(wait_diff_tab(), true)
	eq(tab_count(), before + 1)
	eq(child.lua_get("DiffPreview.state.diff_tab == vim.api.nvim_get_current_tabpage()"), true)
end)

T["file-tree: Neo-tree is opened and focused in diff tab"] = H.xfail(CODEDIFF_CRASH, function()
	open_diff(TRACKED)
	eq(wait_diff_tab(), true)

	eq(child.wait([[vim.bo.filetype == "neo-tree"]], ASYNC_MS), true)
	eq(current_is_neo_tree(), true)
end)

T["file-tree: File outside a repository"] = function()
	local outside = vim.fn.tempname() .. ".txt"
	vim.fn.writefile({ "x" }, outside)
	child.lua([[
		Notes = {}
		vim.notify = function(msg, level) table.insert(Notes, { msg = msg, level = level }) end
	]])
	local before = tab_count()
	open_diff(outside)

	eq(child.wait("#Notes > 0", ASYNC_MS), true)
	local note = child.lua_get("Notes[1]")
	eq({ vim.startswith(note.msg, "Git root error:"), note.level }, { true, vim.log.levels.ERROR })
	eq(tab_count(), before)
end

T["file-tree: Focus moves to neo-tree"] = function()
	child.cmd("Neotree filesystem")
	eq(child.wait([[vim.bo.filetype == "neo-tree"]], ASYNC_MS), true)
	child.cmd("wincmd l")

	eq(child.lua_get("DiffPreview.focus_neo_tree()"), true)
	eq(current_is_neo_tree(), true)
end

T["file-tree: j skips directories and previews next file"] = function()
	start_repo()
	open_git_status(repo_path("b/y.lua"))
	cursor_on(repo_path("a/x.lua"))

	child.type_keys("j")

	eq(cursor_path(), repo_path("b/y.lua"))
	eq(child.lua_get("DiffPreview.state.current_file"), repo_path("b/y.lua"))
end

T["file-tree: k skips directories and previews previous file"] = function()
	start_repo()
	open_git_status(repo_path("b/y.lua"))
	cursor_on(repo_path("b/y.lua"))

	child.type_keys("k")

	eq(cursor_path(), repo_path("a/x.lua"))
	eq(child.lua_get("DiffPreview.state.current_file"), repo_path("a/x.lua"))
end

T["file-tree: Deleted file is not previewed"] = function()
	start_repo()
	open_git_status(repo_path("z.lua"))
	cursor_on(repo_path("b/y.lua"))
	child.lua("DiffPreview.state.current_file = ...", { repo_path("b/y.lua") })

	child.type_keys("j")

	eq(cursor_path(), repo_path("z.lua"))
	eq(child.lua_get("DiffPreview.state.current_file"), repo_path("b/y.lua"))
end

--- Call `open_diff(a)` then `open_diff(b)` in one RPC, well within the 50 ms debounce.
---@param a string
---@param b string
local function open_diff_rapidly(a, b)
	child.lua("local a, b = ...; DiffPreview.open_diff(a); DiffPreview.open_diff(b)", { a, b })
end

--- Count tab pages created from now on in the child global `TabsCreated`.
local function count_new_tabs()
	child.lua([[
		TabsCreated = 0
		vim.api.nvim_create_autocmd("TabNew", { callback = function() TabsCreated = TabsCreated + 1 end })
	]])
end

T["file-tree: Rapid calls are debounced"] = H.xfail(CODEDIFF_CRASH, function()
	start_repo()
	count_new_tabs()

	open_diff_rapidly(repo_path("a/x.lua"), repo_path("b/y.lua"))

	eq(wait_diff_tab(), true)
	eq(child.lua_get("TabsCreated"), 1)
	eq(child.lua_get(diff_tab_shows(repo_path("b/y.lua"))), true)
end)

return T
