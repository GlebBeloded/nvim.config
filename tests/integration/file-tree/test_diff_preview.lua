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

return T
