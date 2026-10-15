local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

--- Git-tracked files of this checkout used as diff targets.
local TRACKED = vim.fs.joinpath(H.root, "lua/gleb/file_tree/diff_preview.lua")
local TRACKED_B = vim.fs.joinpath(H.root, "lua/gleb/file_tree/init.lua")
-- generous: async results land after >3 s under the 12-worker `make check` load
local ASYNC_MS = 10000

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

---@return integer
local function focus_guard_count()
	return child.lua_get([[#vim.api.nvim_get_autocmds({ group = "gleb_file_tree_focus_guard" })]])
end

---@param path string
local function open_diff(path)
	child.lua("DiffPreview.open_diff(...)", { path })
end

---@return boolean
local function wait_diff_tab()
	return child.wait("DiffPreview.state.diff_tab ~= nil", ASYNC_MS)
end

--- Replace codediff's view.create with a plain tabnew, so tab-state cases run while
--- fix-diff-preview-codediff-crash is queued; they assert diff_preview state, not codediff rendering.
local function stub_codediff_view()
	child.lua([[require("codediff.ui.view").create = function() vim.cmd("tabnew") end]])
end

--- Lua expression: a window of the diff tab shows the buffer of `path`.
---@param path string
---@return string
local function diff_tab_shows(path)
	return ("DiffTabShows(%q)"):format(path)
end

--- Lua expression: the current tab has a window whose buffer is `path` and not a tree.
---@param path string
---@return string
local function editing(path)
	return (
		"vim.iter(vim.api.nvim_tabpage_list_wins(0)):any(function(win) "
		.. "local buf = vim.api.nvim_win_get_buf(win) "
		.. "return vim.bo[buf].filetype ~= 'neo-tree' and vim.api.nvim_buf_get_name(buf) == %q end)"
	):format(path)
end

---@return boolean
local function neo_tree_in_current_tab()
	return child.lua_get([[vim.iter(vim.api.nvim_tabpage_list_wins(0)):any(function(win)
		return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree"
	end)]])
end

---@return string[] `neo_tree_source` of every tree window in the current tab
local function tree_sources_in_current_tab()
	return child.lua_get(
		[[vim.iter(vim.api.nvim_tabpage_list_wins(0)):map(vim.api.nvim_win_get_buf):filter(function(buf)
		return vim.bo[buf].filetype == "neo-tree"
	end):map(function(buf) return vim.b[buf].neo_tree_source end):totable()]]
	)
end

--- Lua expression: a `filesystem` tree in the current tab has its cursor on `path`.
---@param path string
---@return string
local function filesystem_reveals(path)
	return ([[(function(path)
		local state = require("neo-tree.sources.manager").get_state("filesystem")
		if not (state.winid and vim.api.nvim_win_is_valid(state.winid) and state.tree) then
			return false
		end
		local buf = vim.api.nvim_win_get_buf(state.winid)
		local node = state.tree:get_node()
		return vim.api.nvim_win_get_tabpage(state.winid) == vim.api.nvim_get_current_tabpage()
			and vim.b[buf].neo_tree_source == "filesystem"
			and node ~= nil and node.path == path
	end)(%q)]]):format(path)
end

--- Call `open_diff(path)` and keep the child's clock at the call in `OpenDiffAt`.
---@param path string
local function open_diff_timed(path)
	child.lua("OpenDiffAt = vim.uv.now(); DiffPreview.open_diff(...)", { path })
end

--- Enter the first non-tree, non-empty-filetype window of the current tab with
--- `vim.uv.now()` reading `after_ms` past the `open_diff_timed` call: a fake clock
--- for the synchronous `WinEnter`, so a slow diff view cannot miss the window.
---@param after_ms integer
local function enter_diff_window_at(after_ms)
	child.lua(
		[[local now, after_ms = vim.uv.now, ...
		local win = vim.iter(vim.api.nvim_tabpage_list_wins(0)):find(function(w)
			local ft = vim.bo[vim.api.nvim_win_get_buf(w)].filetype
			return ft ~= "neo-tree" and ft ~= ""
		end)
		assert(win, "no diff window in the current tab")
		vim.uv.now = function() return OpenDiffAt + after_ms end
		local ok, err = pcall(vim.api.nvim_set_current_win, win)
		vim.uv.now = now
		assert(ok, err)]],
		{ after_ms }
	)
end

--- Focus the tree and press `keys` in one RPC, so scheduled focus changes of the
--- diff view cannot move the cursor out of the tree in between.
---@param keys string
---@return boolean focused whether a neo-tree window got the keys
local function press_in_tree(keys)
	return child.lua(
		[[if not DiffPreview.focus_neo_tree() then
			return false
		end
		vim.api.nvim_feedkeys(vim.keycode(...), "mx", false)
		return true]],
		{ keys }
	)
end

--- Open the preview of `path` and wait until its diff tab shows it with the tree focused.
---@param path string
---@return boolean
local function preview(path)
	open_diff(path)
	return child.wait(diff_tab_shows(path) .. " and vim.bo.filetype == 'neo-tree'", ASYNC_MS)
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

T["file-tree: Diff tab is created"] = function()
	local before = tab_count()
	open_diff(TRACKED)

	eq(wait_diff_tab(), true)
	eq(tab_count(), before + 1)
	eq(child.lua_get("DiffPreview.state.diff_tab == vim.api.nvim_get_current_tabpage()"), true)
end

T["file-tree: Neo-tree is opened and focused in diff tab"] = function()
	open_diff(TRACKED)
	eq(wait_diff_tab(), true)

	eq(child.wait([[vim.bo.filetype == "neo-tree"]], ASYNC_MS), true)
	eq(current_is_neo_tree(), true)
end

T["file-tree: Return clears tab state and focus guard"] = function()
	stub_codediff_view()
	open_diff(TRACKED)
	eq(wait_diff_tab(), true)
	eq(focus_guard_count() > 0, true)

	child.lua("DiffPreview.return_to_original()")

	eq(child.lua_get("DiffPreview.state.original_tab"), vim.NIL)
	eq(child.lua_get("DiffPreview.state.diff_tab"), vim.NIL)
	eq(child.lua_get("DiffPreview.state.navigating_until"), 0)
	eq(focus_guard_count(), 0)
end

T["file-tree: Next preview records the new original tab"] = function()
	stub_codediff_view()
	open_diff(TRACKED)
	eq(wait_diff_tab(), true)
	child.lua("DiffPreview.return_to_original()")
	child.cmd("tabnew")
	local second = child.api.nvim_get_current_tabpage()

	open_diff(TRACKED_B)
	eq(wait_diff_tab(), true)

	eq(child.lua_get("DiffPreview.state.original_tab"), second)
	child.lua("DiffPreview.return_to_original()")
	eq(child.api.nvim_get_current_tabpage(), second)
end

T["file-tree: Return cancels a pending preview"] = function()
	stub_codediff_view()
	local before = tab_count()
	open_diff(TRACKED)
	child.lua("DiffPreview.return_to_original()")

	eq(child.wait("DiffPreview.state.diff_tab ~= nil", 300), false)
	eq(tab_count(), before)
	eq(child.lua_get("DiffPreview.state.original_tab"), vim.NIL)
end

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

--- Spy on the diff work for a file: paths passed to codediff's `get_git_root` (first step
--- of every diff open) land in `GitRootCalls`, repo-relative paths passed to its
--- `view.create` in `ViewCreates`; both still call through.
local function spy_diff_work()
	child.lua([[
		GitRootCalls, ViewCreates = {}, {}
		local git, view = require("codediff.core.git"), require("codediff.ui.view")
		local get_git_root, create = git.get_git_root, view.create
		git.get_git_root = function(path, ...)
			table.insert(GitRootCalls, path)
			return get_git_root(path, ...)
		end
		view.create = function(session_config, ...)
			table.insert(ViewCreates, session_config.modified.relative)
			return create(session_config, ...)
		end
	]])
end

T["file-tree: Rapid calls are debounced"] = function()
	start_repo()
	count_new_tabs()
	spy_diff_work()

	open_diff_rapidly(repo_path("a/x.lua"), repo_path("b/y.lua"))

	-- right after the calls return, before the debounce timer fires: no diff work yet
	eq(
		child.lua_get("{ GitRootCalls, ViewCreates, TabsCreated, DiffPreview.state.diff_tab == nil }"),
		{ {}, {}, 0, true }
	)
	eq(wait_diff_tab(), true)
	eq(child.lua_get(diff_tab_shows(repo_path("b/y.lua"))), true)
	eq(child.lua_get("GitRootCalls"), { repo_path("b/y.lua") })
	eq(child.lua_get("ViewCreates"), { "b/y.lua" })
	eq(child.lua_get("TabsCreated"), 1)
end

T["file-tree: Diff tab is reused across files"] = function()
	start_repo()
	eq(preview(repo_path("a/x.lua")), true)

	eq(preview(repo_path("b/y.lua")), true)

	eq(tab_count(), 2)
	eq(child.lua_get("DiffPreview.state.current_file"), repo_path("b/y.lua"))
end

T["file-tree: Focus guard pulls focus back during navigation"] = function()
	start_repo()
	open_diff_timed(repo_path("a/x.lua"))
	eq(child.wait(diff_tab_shows(repo_path("a/x.lua")), ASYNC_MS), true)

	enter_diff_window_at(100)

	eq(child.wait([[vim.bo.filetype == "neo-tree"]], ASYNC_MS), true)
end

T["file-tree: Enter opens file and switches to filesystem tree"] = function()
	start_repo()
	open_git_status(repo_path("a/x.lua"))
	cursor_on(repo_path("a/x.lua"))

	child.type_keys("<CR>")

	eq(child.wait(filesystem_reveals(repo_path("a/x.lua")), ASYNC_MS), true)
	eq(child.lua_get(editing(repo_path("a/x.lua"))), true)
	eq(child.api.nvim_buf_get_name(0), repo_path("a/x.lua"))
	eq(current_is_neo_tree(), false)
	eq(tree_sources_in_current_tab(), { "filesystem" })
	eq(tab_count(), 1)
	eq(child.lua_get("DiffPreview.state.diff_tab"), vim.NIL)
end

T["file-tree: o and l keep native open in git status tree"] = function()
	for index, key in ipairs({ "o", "l" }) do
		if index > 1 then
			start()
		end
		start_repo()
		eq(preview(repo_path("a/x.lua")), true)
		local diff_tab = child.lua_get("DiffPreview.state.diff_tab")
		cursor_on(repo_path("b/y.lua"))

		eq(press_in_tree(key), true)

		eq(child.wait(editing(repo_path("b/y.lua")), ASYNC_MS), true)
		eq(tree_sources_in_current_tab(), { "git_status" })
		eq(child.lua_get("DiffPreview.state.diff_tab"), diff_tab)
		eq(child.api.nvim_tabpage_is_valid(diff_tab), true)
	end
end

T["file-tree: q closes preview and tree"] = function()
	start_repo()
	local original_tab = child.api.nvim_get_current_tabpage()
	eq(preview(repo_path("a/x.lua")), true)
	local diff_tab = child.lua_get("DiffPreview.state.diff_tab")

	eq(press_in_tree("q"), true)

	eq(child.api.nvim_get_current_tabpage(), original_tab)
	eq(child.api.nvim_tabpage_is_valid(diff_tab), false)
	eq(child.lua_get("DiffPreview.state.current_file"), vim.NIL)
	eq(child.lua_get("DiffPreview.state.original_tab"), vim.NIL)
	eq(neo_tree_in_current_tab(), false)
end

return T
