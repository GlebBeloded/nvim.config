-- E2E workflow: Cmd+G opens the owned changes review, and `]f`/`]c` step
-- through its changed files and changes. Cases share the stack and run in order.
local MiniTest = require("mini.test")
local E = require("tests.e2e.alacritty")
local F = require("tests.fixtures")
local S = require("tests.shortcuts.stack")

local eq = MiniTest.expect.equality

---@type e2e.Stack?
local stack
---@type string?
local skipped
---@type fixtures.Manifest
local manifest

---@param dir string
---@return string
local function copy_dirty(dir)
	local root
	root, manifest = F.copy("dirty", dir .. "/work")
	return root
end

local function start()
	stack, skipped = E.start_or_skip({ cwd = copy_dirty, layout = "nvim", columns = 100, lines = 30 })
	if stack then
		-- Mason's bin directory is isolated in the sandbox; opening lib/c.lua would
		-- otherwise let null-ls report missing selene through a hit-enter prompt.
		stack:lua([[require("null-ls").disable({ name = "selene" })]])
	end
end

local function stop()
	if stack then
		stack:stop()
		stack = nil
	end
end

---@return e2e.Stack
local function get()
	if skipped then
		MiniTest.skip("SKIPPED (reason on the first line)")
	end
	return assert(stack, "e2e stack not started")
end

local T = MiniTest.new_set({ hooks = { pre_once = start, post_once = stop } })

---@class changes_review.Entry
---@field path string
---@field staged boolean
---@field unstaged boolean
---@field untracked boolean

---@param entries changes_review.Entry[]
---@return changes_review.Entry[]
local function sorted(entries)
	local copy = vim.deepcopy(entries)
	table.sort(copy, function(a, b)
		return a.path < b.path
	end)
	return copy
end

---@return changes_review.Entry[]
local function expected_entries()
	local by_path = {}
	for _, entry in ipairs(manifest.files) do
		local combined = by_path[entry.path]
			or { path = entry.path, staged = false, unstaged = false, untracked = false }
		combined.staged = combined.staged or entry.staged
		combined.unstaged = combined.unstaged or not entry.staged
		combined.untracked = combined.untracked or entry.untracked
		by_path[entry.path] = combined
	end
	return sorted(vim.tbl_values(by_path))
end

local PANEL_ENTRIES = [[local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
	if not panel or #panel.rows == 0 then return vim.NIL end
	local entries = {}
	for _, row in ipairs(panel.rows) do
		if row.kind == "file" then
			local xy = row.xy or ".."
			table.insert(entries, {
				path = row.path,
				staged = xy:sub(1, 1) ~= ".",
				unstaged = row.status == "untracked" or xy:sub(2, 2) ~= ".",
				untracked = row.status == "untracked",
			})
		end
	end
	return entries]]

local PANEL_CURRENT = [[local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
	local current_row = vim.api.nvim_win_get_cursor(panel.win)[1]
	local current = 0
	for index, row in ipairs(panel.rows) do
		if row.kind == "file" then current = current + 1 end
		if index == current_row then return current end
	end
	return vim.NIL]]

local PANEL_COLUMN = [=[local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
	return vim.fn.win_screenpos(panel.win)[2]]=]

local VIEW = [[local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
	local view = panel and panel.diff_view
	return view and { path = view.relpath, id = tostring(view) } or vim.NIL]]

local FOCUS_DIFF = [[local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
	vim.api.nvim_set_current_win(panel.diff_view.right_win)]]

local SELECT_FILE = [[local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
	for index, row in ipairs(panel.rows) do
		if row.kind == "file" and row.path == ... then
			vim.api.nvim_win_set_cursor(panel.win, { index, 0 })
			require("gleb.git.changes.view").review(panel)
			return
		end
	end
	error("file row not found: " .. ...)]]

local DIFF_STATE = [[local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
	local view = panel.diff_view
	return { win = view.right_win, cursor = vim.api.nvim_win_get_cursor(view.right_win)[1] }]]

---@param s e2e.Stack
---@return changes_review.Entry[]
local function wait_panel(s)
	local entries
	S.wait_for(function()
		entries = s:lua(PANEL_ENTRIES)
		return entries ~= vim.NIL and entries ~= nil
	end, "changes panel with files")
	return entries
end

---@param s e2e.Stack
---@return changes_review.Entry[]
local function ensure_review(s)
	local entries = s:lua(PANEL_ENTRIES)
	if entries == vim.NIL or entries == nil then
		E.burst(s, function()
			E.press(s, "cmd+g")
			entries = wait_panel(s)
		end)
	end
	return entries
end

---@class changes_review.View
---@field path string
---@field id string

---@param s e2e.Stack
---@return changes_review.View
local function wait_view(s)
	local view
	S.wait_for(function()
		view = s:lua(VIEW)
		return view ~= vim.NIL and view ~= nil
	end, "owned changes diff view")
	return view
end

---@param s e2e.Stack
---@param from changes_review.View
---@return changes_review.View
local function next_file(s, from)
	local view
	E.press(s, { "]", "f" })
	S.wait_for(function()
		view = s:lua(VIEW)
		return view ~= vim.NIL and view.id ~= from.id
	end, "changes diff after " .. from.path)
	return view
end

T["git: Cmd+G opens the changes review of a dirty repo"] = function()
	local s = get()
	local entries = ensure_review(s)
	local view = wait_view(s)

	eq(s:lua(PANEL_COLUMN), 1)
	eq(sorted(entries), expected_entries())
	eq(view.path, "lib/c.lua")
end

T["git: ]f steps to the next changed file in the changes review"] = function()
	local s = get()
	local entries = ensure_review(s)
	local view = wait_view(s)
	eq(s:lua(PANEL_CURRENT), 1)
	s:lua(FOCUS_DIFF)
	local visited = { view.path }
	E.burst(s, function()
		for _ = 2, #entries do
			view = next_file(s, view)
			table.insert(visited, view.path)
		end
	end)

	eq(
		visited,
		vim.tbl_map(function(entry)
			return entry.path
		end, entries)
	)
	eq(
		sorted(vim.tbl_map(function(path)
			return { path = path }
		end, visited)),
		sorted(vim.tbl_map(function(entry)
			return { path = entry.path }
		end, expected_entries()))
	)
end

T["git: ]c steps to the next change in the changes review"] = function()
	local s = get()
	ensure_review(s)
	local view = wait_view(s)
	s:lua(SELECT_FILE, { "b.txt" })
	S.wait_for(function()
		view = s:lua(VIEW)
		return view ~= vim.NIL and view.path == "b.txt"
	end, "changes diff for b.txt")
	s:lua(FOCUS_DIFF)
	eq(view.path, "b.txt")

	local hunks = manifest.hunks["b.txt"]
	local state = s:lua(DIFF_STATE)
	s:lua("vim.api.nvim_win_set_cursor(...)", { state.win, { hunks[1], 0 } })
	E.burst(s, function()
		E.press(s, { "]", "c" })
		S.wait_for(function()
			return s:lua(DIFF_STATE).cursor == hunks[2]
		end, "cursor on the second change of b.txt")
	end)
	eq(s:lua(DIFF_STATE).cursor, hunks[2])
end

return T
