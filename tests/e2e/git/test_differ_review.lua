-- E2E workflow: Cmd+G on a fresh copy of the dirty fixture (tests/fixtures/build.sh)
-- opens differ, and `]f`/`]c` step through its files and hunks. Real key presses,
-- state read over RPC; expected files and hunks come from the fixture's manifest.
-- Cases share the stack and run in order.
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

---@param dir string the stack's temp dir
---@return string
local function copy_dirty(dir)
	local root
	root, manifest = F.copy("dirty", dir .. "/work")
	return root
end

local function start()
	stack, skipped = E.start_or_skip({ cwd = copy_dirty, layout = "nvim", columns = 100, lines = 30 })
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

---@param entries fixtures.Entry[]
---@return fixtures.Entry[] sorted copy, for set comparison
local function sorted(entries)
	local copy = vim.deepcopy(entries)
	table.sort(copy, function(a, b)
		if a.path ~= b.path then
			return a.path < b.path
		end
		return tostring(a.staged) < tostring(b.staged)
	end)
	return copy
end

---@param entries fixtures.Entry[]
---@return string[] paths in entry order
local function paths(entries)
	return vim.tbl_map(function(entry)
		return entry.path
	end, entries)
end

---@param list string[]
---@param first integer
---@return string[] `list` rotated to start at index `first`
local function rotated(list, first)
	local out = {}
	for i = 0, #list - 1 do
		table.insert(out, list[(first - 1 + i) % #list + 1])
	end
	return out
end

---@param list string[]
---@return string[] sorted copy
local function sorted_paths(list)
	local copy = vim.deepcopy(list)
	table.sort(copy)
	return copy
end

-- panel entries in the panel's row order (its sections and tree listing), as
-- fixtures.Entry (nil while no panel)
local PANEL_ENTRIES = [[local panel = require("differ.panel").current()
	if not panel or #panel.sections == 0 then return vim.NIL end
	local entries = {}
	for _, row in ipairs(panel.meta) do
		if row.kind == "file" then
			local entry = row.entry
			table.insert(entries, { path = entry.path, staged = entry.staged == true, untracked = entry.status == "?" })
		end
	end
	return entries]]

-- 1-based index of the panel's current entry among its file rows
local PANEL_CURRENT = [[local panel = require("differ.panel").current()
	local current, index = panel:current_entry(), 0
	for _, row in ipairs(panel.meta) do
		if row.kind == "file" then
			index = index + 1
			if row.entry == current then return index end
		end
	end
	return vim.NIL]]

local PANEL_COLUMN = [[local panel = require("differ.panel").current()
	return vim.fn.win_screenpos(panel.winid)[2] ]]

-- the shown diff: its path and model identity (the staged and unstaged d.txt share a path)
local VIEW = [[local view = require("differ").active_view()
	return view and { path = view.model.path, id = tostring(view.model) } or vim.NIL]]

local FOCUS_DIFF = [[local view = require("differ").active_view()
	vim.api.nvim_set_current_win(view.columns[#view.columns].winid)]]

-- the last column's window, cursor line and buffer line of new-file line `...`
local DIFF_STATE = [[local view = require("differ").active_view()
	local column = view.columns[#view.columns]
	return { win = column.winid, cursor = vim.api.nvim_win_get_cursor(column.winid)[1],
		from_new = vim.tbl_map(function(line) return column.map.from_new[line] end, { ... }) }]]

local WINBAR = [[local win = ...
	return vim.api.nvim_eval_statusline(vim.wo[win].winbar, { winid = win, use_winbar = true }).str]]

---@param s e2e.Stack
---@return fixtures.Entry[]
local function wait_panel(s)
	local entries
	S.wait_for(function()
		entries = s:lua(PANEL_ENTRIES)
		return entries ~= vim.NIL and entries ~= nil
	end, "differ panel with sections")
	return entries
end

--- Differ open on the dirty copy (opened unless an earlier case left it open).
---@param s e2e.Stack
---@return fixtures.Entry[] panel entries in section order
local function ensure_differ(s)
	local entries = s:lua(PANEL_ENTRIES)
	if entries ~= vim.NIL and entries ~= nil then
		return entries
	end
	E.burst(s, function()
		E.press(s, "cmd+g")
		entries = wait_panel(s)
	end)
	return entries
end

---@class differ_review.View
---@field path string
---@field id string

---@param s e2e.Stack
---@return differ_review.View
local function wait_view(s)
	local view
	S.wait_for(function()
		view = s:lua(VIEW)
		return view ~= vim.NIL and view ~= nil
	end, "a differ diff view")
	return view
end

--- Press `]f` and wait for the next diff.
---@param s e2e.Stack
---@param from differ_review.View
---@return differ_review.View
local function next_file(s, from)
	local view
	E.press(s, { "]", "f" })
	S.wait_for(function()
		view = s:lua(VIEW)
		return view ~= vim.NIL and view.id ~= from.id
	end, "differ diff after " .. from.path)
	return view
end

T["git: Cmd+G opens differ listing every change of a dirty repo"] = function()
	local s = get()
	local entries = ensure_differ(s)
	eq(s:lua(PANEL_COLUMN), 1)
	eq(sorted(entries), sorted(manifest.files))
	eq(sorted_paths(paths(manifest.files)), { "a.txt", "b.txt", "d.txt", "d.txt", "lib/c.lua", "new.txt" })
end

T["git: ]f steps to the next changed file in differ"] = function()
	local s = get()
	local entries = ensure_differ(s)
	local view = wait_view(s)
	local first = s:lua(PANEL_CURRENT)
	s:lua(FOCUS_DIFF)
	local visited = { view.path }
	E.burst(s, function()
		for _ = 2, #entries do
			view = next_file(s, view)
			table.insert(visited, view.path)
		end
	end)
	eq(visited, rotated(paths(entries), first))
	eq(sorted_paths(visited), sorted_paths(paths(manifest.files)))
end

T["git: ]c steps to the next hunk in differ"] = function()
	local s = get()
	local entries = ensure_differ(s)
	local view = wait_view(s)
	s:lua(FOCUS_DIFF)
	E.burst(s, function()
		for _ = 1, #entries do
			if view.path == "b.txt" then
				break
			end
			view = next_file(s, view)
		end
	end)
	eq(view.path, "b.txt")
	s:lua(FOCUS_DIFF)
	local hunks = manifest.hunks["b.txt"]
	local state = s:lua(DIFF_STATE, hunks)
	s:lua("vim.api.nvim_win_set_cursor(...)", { state.win, { state.from_new[1], 0 } })
	E.burst(s, function()
		E.press(s, { "]", "c" })
		S.wait_for(function()
			return s:lua(DIFF_STATE, hunks).cursor == state.from_new[2]
		end, "cursor on the second hunk of b.txt")
	end)
	eq(s:lua(WINBAR, { state.win }):find("hunk 2/2", 1, true) ~= nil, true)
end

return T
