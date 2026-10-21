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

local PANEL_CYCLE_STATE = [[local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
	if not panel then return vim.NIL end
	local summary
	for _, row in ipairs(panel.rows) do
		if row.kind == "summary" then summary = row.label end
	end
	return {
		active = panel.active_tab,
		local_count = panel.local_count,
		branch_count = panel.branch_count,
		summary = summary,
	}]]

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

T["git: Real Cmd+G presses cycle the changes tabs"] = function()
	stop()
	stack, skipped = E.start_or_skip({
		cwd = function(dir)
			local root = F.copy("billing-branch", dir .. "/work")
			return root
		end,
		layout = "nvim",
		columns = 100,
		lines = 30,
	})
	local s = get()
	s:lua([[
		vim.env.FAKE_GH_CODE = "1"
		vim.env.FAKE_GH_STDOUT = nil
		vim.lsp.enable("gopls", false)
		require("null-ls").disable({})
	]])

	E.press(s, "cmd+g")
	local state
	S.wait_for(function()
		state = s:lua(PANEL_CYCLE_STATE)
		return state ~= vim.NIL and state.active == "local" and state.local_count == 3 and state.branch_count == 4
	end, "Local 3 tab after first Cmd+G")
	eq({ state.active, state.local_count }, { "local", 3 })

	E.press(s, "cmd+g")
	S.wait_for(function()
		state = s:lua(PANEL_CYCLE_STATE)
		return state ~= vim.NIL
			and state.active == "branch"
			and state.branch_count == 4
			and state.summary == "3 commits · merge-base 4ccefde"
	end, "Branch 4 tab after second Cmd+G")
	eq({ state.active, state.branch_count, state.summary }, {
		"branch",
		4,
		"3 commits · merge-base 4ccefde",
	})

	E.press(s, "cmd+g")
	S.wait_for(function()
		return s:lua(PANEL_CYCLE_STATE) == vim.NIL
	end, "closed changes panel after third Cmd+G")
end

T["git: Real key presses move, scroll and edit in the Branch diff"] = function()
	stop()
	stack, skipped = E.start_or_skip({
		cwd = function(dir)
			local root = F.copy("billing-branch", dir .. "/work")
			return root
		end,
		layout = "nvim",
		columns = 100,
		lines = 30,
	})
	local s = get()
	s:lua([[
		vim.env.FAKE_GH_CODE = "1"
		vim.env.FAKE_GH_STDOUT = nil
		vim.lsp.enable("gopls", false)
		require("null-ls").disable({})
		vim.cmd.edit(vim.fs.joinpath(vim.uv.cwd(), "internal/billing/invoice.go"))
	]])

	E.press(s, "cmd+g")
	S.wait_for(function()
		local state = s:lua(PANEL_CYCLE_STATE)
		return state ~= vim.NIL and state.active == "local" and state.local_count == 3 and state.branch_count == 4
	end, "Local tab after first Cmd+G")
	E.press(s, "cmd+g")
	S.wait_for(function()
		local state = s:lua(PANEL_CYCLE_STATE)
		return state ~= vim.NIL and state.active == "branch" and state.branch_count == 4
	end, "Branch tab after second Cmd+G")
	local movement = s:lua([[return (function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local current = vim.api.nvim_win_get_cursor(panel.win)[1]
		for index, row in ipairs(panel.rows) do
			if row.kind == "file" then
				return { key = index > current and "j" or "k", count = math.abs(index - current), target = index }
			end
		end
		error("Branch tab has no file row")
	end)()]])
	for _ = 1, movement.count do
		E.press(s, movement.key)
	end
	S.wait_for(function()
		return s:lua([[return (function()
			local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return vim.api.nvim_win_get_cursor(panel.win)[1]
		end)()]]) == movement.target
	end, "first Branch file selected")
	S.wait_for(function()
		return s:lua([[return (function()
			local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return panel and panel.diff_view ~= nil and panel.diff_path ~= nil
				and panel.diff_path:sub(1, 7) == "branch:"
				and panel.diff_view.relpath == "internal/billing/invoice.go"
		end)()]]) == true
	end, "Branch diff after selecting its first file")

	local initial = s:lua([[return (function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local view = panel.diff_view
		return {
			panel_win = panel.win,
			current_win = vim.api.nvim_get_current_win(),
			left_win = view.left_win,
			right_win = view.right_win,
			right_buf = view.right_buf,
			first_change = view.fragments[1].start2 + 1,
			right_cursor = vim.api.nvim_win_get_cursor(view.right_win)[1],
			changedtick = view.changedtick,
			name = vim.api.nvim_buf_get_name(view.right_buf),
			modifiable = vim.bo[view.right_buf].modifiable,
		}
	end)()]])
	eq(initial.current_win, initial.panel_win)
	eq(initial.right_cursor, initial.first_change)
	eq(initial.modifiable, true)
	assert(initial.name ~= "", "Branch right pane is not a named working-file buffer")

	E.press(s, "cmd+l")
	S.wait_for(function()
		return s:lua([[return (function()
			local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return vim.api.nvim_get_current_win() == panel.diff_view.left_win
		end)()]]) == true
	end, "first Cmd+L entered the left diff pane")
	E.press(s, "cmd+l")
	S.wait_for(function()
		return s:lua([[return (function()
			local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return vim.api.nvim_get_current_win() == panel.diff_view.right_win
		end)()]]) == true
	end, "second Cmd+L entered the right diff pane")
	local entered = s:lua("return vim.api.nvim_win_get_cursor(0)[1]")
	eq(entered, initial.first_change)
	for step = 1, 2 do
		E.press(s, "j")
		local cursor_state
		S.wait_for(function()
			cursor_state = s:lua(
				[[return (function(previous_line)
				local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				local view = panel.diff_view
				local right = vim.api.nvim_win_get_cursor(view.right_win)[1]
				local left = vim.api.nvim_win_get_cursor(view.left_win)[1]
				return {
					right = right,
					moved = right > previous_line,
					synced = left == require("gleb.diff.view.layout").transfer_line(view.layout, "right", right),
				}
			end)(...)]],
				{ entered + step - 1 }
			)
			return cursor_state.moved and cursor_state.synced
		end, ("j press %d moved the Branch cursor"):format(step))
		eq(cursor_state.right, entered + step)
	end

	local edit = s:lua([[return (function()
		local cursor = vim.api.nvim_win_get_cursor(0)
		local line = vim.api.nvim_get_current_line()
		return {
			line = cursor[1],
			col = cursor[2],
			before = line,
			expected = line:sub(1, cursor[2]) .. line:sub(cursor[2] + 2),
		}
	end)()]])
	E.press(s, "x")
	S.wait_for(function()
		return s:lua(
			[[
			return vim.bo.modified and vim.api.nvim_get_current_line() == ...
			]],
			{ edit.expected }
		) == true
	end, "x deleted the character under the Branch cursor")
	E.press(s, { "shift+;", "w", "return" })
	S.wait_for(function()
		return s:lua(
			[[return (function(path, line, expected, previous_tick)
				local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return panel and panel.diff_view and panel.diff_view.changedtick > previous_tick
					and panel.diff_view.changedtick == vim.api.nvim_buf_get_changedtick(panel.diff_view.right_buf)
					and not vim.bo[panel.diff_view.right_buf].modified
					and vim.fn.readfile(path)[line] == expected
			end)(...)]],
			{ initial.name, edit.line, edit.expected, initial.changedtick }
		) == true
	end, ":w saved the deletion and redrew the Branch diff")

	local screen = s:lua(
		[[return (function(expected_line)
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local view = panel.diff_view
		local cursor = vim.api.nvim_win_get_cursor(view.right_win)
		local position = vim.fn.screenpos(view.right_win, cursor[1], cursor[2] + 1)
		return {
			current_win = vim.api.nvim_get_current_win(),
			right_win = view.right_win,
			cursor_line = cursor[1],
			row = position.row,
			col = position.col,
			right_col = vim.fn.win_screenpos(view.right_win)[2],
			line = vim.api.nvim_buf_get_lines(view.right_buf, cursor[1] - 1, cursor[1], false)[1],
			expected = expected_line,
		}
	end)(...)]],
		{ edit.expected }
	)
	local dump = s:zellij("dump-screen")
	local rows = vim.split(dump, "\n", { plain = true })
	eq(screen.current_win, screen.right_win)
	eq(screen.cursor_line, initial.first_change + 2)
	assert(screen.col >= screen.right_col, "cursor was not inside the right diff pane")
	eq(screen.line, screen.expected)
	local visible = screen.expected:sub(1, 18)
	assert(
		rows[screen.row] and rows[screen.row]:find(visible, 1, true),
		("screen dump omitted row %d (%s):\n%s"):format(screen.row, screen.expected, dump)
	)
end

return T
