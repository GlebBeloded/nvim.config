local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local root

---@return integer
local function async_timeout()
	return math.floor(5000 * H.load_factor())
end

local function report_pull_request()
	local output = vim.fn.tempname()
	local base = vim.trim(H.git(root, { "rev-parse", "origin/main" }))
	local head = vim.trim(H.git(root, { "rev-parse", "HEAD" }))
	vim.fn.writefile({
		vim.json.encode({
			number = 482,
			url = "https://example.test/pull/482",
			state = "OPEN",
			baseRefName = "main",
			baseRefOid = base,
			headRefName = "feat/tax",
			headRefOid = head,
		}),
	}, output)
	child.lua([[vim.env.FAKE_GH_STDOUT = ...; vim.env.FAKE_GH_CODE = "0"]], { output })
end

local function start()
	root = F.copy("billing-branch", vim.fn.tempname() .. "/billing-branch")
	child.start_config({ env = F.go_env() })
	child.wait_very_lazy()
	report_pull_request()
	local invoice = vim.fs.joinpath(root, "internal/billing/invoice.go")
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(invoice))
	child.lua([[require("gleb.git.changes.branch").now = function() return 1767315600 end]])
end

local T = H.child_set(child, start)

---@param active string
---@param right_label? string
local function wait_for_diff(active, right_label)
	assert(
		child.wait(
			string.format(
				[[(function()
					local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
					return panel and panel.tabs_ready and panel.active_tab == %q and panel.diff_view ~= nil
						and panel.diff_path ~= nil and panel.diff_path:sub(1, #%q + 1) == %q .. ":"
						and (%q == "" or panel.diff_view.labels.right == %q)
				end)()]],
				active,
				active,
				active,
				right_label or "",
				right_label or ""
			),
			async_timeout()
		),
		("Changes %s diff did not load"):format(active)
	)
end

local function open_branch_diff()
	child.type_keys("<A-g>")
	wait_for_diff("local")
	child.type_keys("<A-g>")
	wait_for_diff("branch", "Your version")
end

---@param id string
local function open_row(id)
	local movement = child.lua_get(
		[[(function(wanted)
			local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			local current = vim.api.nvim_win_get_cursor(panel.win)[1]
			for index, row in ipairs(panel.rows) do
				if row.id == wanted then
					return { key = index > current and "j" or "k", count = math.abs(index - current) }
				end
			end
			error("row not found: " .. wanted)
		end)(...)]],
		{ id }
	)
	for _ = 1, movement.count do
		child.type_keys(movement.key)
	end
end

local function open_commit_diff()
	open_branch_diff()
	child.type_keys("c", "<Esc>")
	assert(
		child.wait(
			[[(function()
				local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return panel and panel.commit_view
					and vim.iter(panel.rows):any(function(row)
						return row.id == "branch:commit:e325463:file:internal/billing/invoice.go"
					end)
			end)()]],
			async_timeout()
		),
		"Branch commits did not load"
	)
	open_row("branch:commit:e325463:file:internal/billing/invoice.go")
	wait_for_diff("branch", "e325463 · wire tax into Total")
end

local function view_state()
	return child.lua_get([[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local view = panel.diff_view
		return {
			panel_win = panel.win,
			current_win = vim.api.nvim_get_current_win(),
			left_cursor = vim.api.nvim_win_get_cursor(view.left_win)[1],
			right_cursor = vim.api.nvim_win_get_cursor(view.right_win)[1],
			left_win = view.left_win,
			right_win = view.right_win,
			right_buf = view.right_buf,
		}
	end)()]])
end

---@param key string
---@param condition string
---@param message string
local function type_and_wait(key, condition, message)
	child.type_keys(key)
	assert(child.wait(condition, async_timeout()), message)
end

---@param key string
---@param previous_line integer
---@param expected_line? integer
---@param check_topline? boolean
local function move_right_and_wait(key, previous_line, expected_line, check_topline)
	child.type_keys(key)
	local expected = expected_line and tostring(expected_line) or "nil"
	local check_top = tostring(check_topline == true)
	local moved = child.wait(
		string.format(
			[[(function(previous, expected, check_top)
				local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				local view = panel and panel.diff_view
				if not view then return false end
				local right = vim.api.nvim_win_get_cursor(view.right_win)[1]
				local left = vim.api.nvim_win_get_cursor(view.left_win)[1]
				local right_top = vim.api.nvim_win_call(view.right_win, function()
					return vim.fn.winsaveview().topline
				end)
				local left_top = vim.api.nvim_win_call(view.left_win, function()
					return vim.fn.winsaveview().topline
				end)
				return right ~= previous and (expected == nil or right == expected)
					and left == require("gleb.diff.view.layout").transfer_line(view.layout, "right", right)
					and (not check_top
						or left_top == require("gleb.diff.view.layout").transfer_line(view.layout, "right", right_top))
			end)(%d, %s, %s)]],
			previous_line,
			expected,
			check_top
		),
		async_timeout()
	)
	if not moved then
		local observed = child.lua_get([[(function()
			local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			local view = panel.diff_view
			local right = vim.api.nvim_win_get_cursor(view.right_win)[1]
			local right_top = vim.api.nvim_win_call(view.right_win, function() return vim.fn.winsaveview().topline end)
			return {
				right = right,
				left = vim.api.nvim_win_get_cursor(view.left_win)[1],
				expected_left = require("gleb.diff.view.layout").transfer_line(view.layout, "right", right),
				right_top = right_top,
				left_top = vim.api.nvim_win_call(view.left_win, function() return vim.fn.winsaveview().topline end),
				expected_left_top = require("gleb.diff.view.layout").transfer_line(view.layout, "right", right_top),
			}
		end)()]])
		error(("Diff panes did not move together after %s: %s"):format(key, vim.inspect(observed)))
	end
	return child.lua_get([[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return vim.api.nvim_win_get_cursor(panel.diff_view.right_win)[1]
	end)()]])
end

T["git: Changes Local diff starts on the first change"] = function()
	child.type_keys("<A-g>")
	wait_for_diff("local")

	local state = view_state()
	eq(state.current_win, state.panel_win)
	eq(state.right_cursor, 11)
	eq(state.left_cursor, 11)
end

T["git: Changes Branch diff starts on the first change"] = function()
	open_branch_diff()

	local state = view_state()
	eq(state.current_win, state.panel_win)
	eq(state.right_cursor, 9)
	eq(state.left_cursor, 9)
end

T["git: Changes commit diff starts on the first change"] = function()
	open_commit_diff()

	local state = view_state()
	eq(state.current_win, state.panel_win)
	eq(state.right_cursor, 9)
	eq(state.left_cursor, 9)
end

T["git: Changes ]f starts the next file on its first change"] = function()
	open_branch_diff()
	local right_win = view_state().right_win
	child.api.nvim_set_current_win(right_win)
	child.type_keys("]f")
	assert(
		child.wait(
			[[(function()
				local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return panel and panel.diff_view
					and panel.diff_view.relpath == "internal/billing/invoice_test.go"
			end)()]],
			async_timeout()
		),
		"Next Branch file did not load"
	)

	local state = child.lua_get([[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local view = panel.diff_view
		return {
			current_win = vim.api.nvim_get_current_win(),
			right_win = view.right_win,
			right_cursor = vim.api.nvim_win_get_cursor(view.right_win)[1],
			first_change = view.fragments[1].start2 + 1,
		}
	end)()]])
	eq(state.current_win, state.right_win)
	eq(state.right_cursor, state.first_change)
end

T["git: Branch diff right pane is the working file"] = function()
	open_branch_diff()

	local state = child.lua_get(
		[[(function(path)
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local view = panel.diff_view
		local starts = vim.iter(view.fragments):map(function(fragment)
			return fragment.start2 + 1
		end):totable()
		return {
			actual_buf = view.right_buf,
			expected_buf = vim.fn.bufnr(path),
			buftype = vim.bo[view.right_buf].buftype,
			modifiable = vim.bo[view.right_buf].modifiable,
			filetype = vim.bo[view.right_buf].filetype,
			lines = vim.api.nvim_buf_get_lines(view.right_buf, 0, -1, false),
			starts = starts,
		}
	end)(...)]],
		{ vim.fs.joinpath(root, "internal/billing/invoice.go") }
	)

	eq(state.actual_buf, state.expected_buf)
	eq(state.buftype, "")
	eq(state.modifiable, true)
	eq(state.filetype, "go")
	eq(state.lines, vim.fn.readfile(vim.fs.joinpath(root, "internal/billing/invoice.go")))
	assert(vim.tbl_contains(state.starts, 11), "uncommitted change was absent")
end

T["git: Branch diff edits are saved and re-diffed"] = function()
	open_branch_diff()
	local before = view_state()
	child.api.nvim_set_current_win(before.right_win)
	child.lua([[BranchEditPath, BranchEditRightWin, BranchExpectedHead = ...]], {
		vim.fs.joinpath(root, "internal/billing/invoice.go"),
		before.right_win,
		vim.split(H.git(root, { "show", "HEAD:internal/billing/invoice.go" }):gsub("\n$", ""), "\n", { plain = true }),
	})
	child.cmd([[11s/ \/\/ invoice number//]])
	child.cmd("write")

	assert(
		child.wait(
			[[(function()
				local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				if not panel or panel.active_tab ~= "branch" or panel.diff_view.right_win ~= BranchEditRightWin then
					return false
				end
				local disk = vim.fn.readfile(BranchEditPath)
				local starts = vim.iter(panel.diff_view.fragments):map(function(fragment)
					return fragment.start2 + 1
				end):totable()
				return vim.deep_equal(disk, BranchExpectedHead)
					and vim.deep_equal(starts, { 9, 18, 22, 32 })
			end)() ]],
			async_timeout()
		),
		"Saved Branch edit did not refresh its owned diff"
	)
end

T["git: Window keys enter the diff panes"] = function()
	child.type_keys("<A-g>")
	wait_for_diff("local")
	local before = child.lua_get([[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local view = panel.diff_view
		return {
			panel_win = panel.win,
			panel_cursor = vim.api.nvim_win_get_cursor(panel.win),
			left_win = view.left_win,
			right_win = view.right_win,
			right_buf = view.right_buf,
			fragments = vim.deepcopy(view.fragments),
		}
	end)()]])

	type_and_wait(
		"<C-l>",
		("vim.api.nvim_get_current_win() == %d"):format(before.left_win),
		"First window-right key did not enter the left diff pane"
	)
	type_and_wait(
		"<C-l>",
		("vim.api.nvim_get_current_win() == %d and vim.api.nvim_win_get_cursor(%d)[1] == 11"):format(
			before.right_win,
			before.right_win
		),
		"Second window-right key did not enter the right diff pane"
	)
	type_and_wait(
		"<C-h>",
		("vim.api.nvim_get_current_win() == %d"):format(before.left_win),
		"First window-left key did not return to the left diff pane"
	)
	type_and_wait(
		"<C-h>",
		("vim.api.nvim_get_current_win() == %d"):format(before.panel_win),
		"Second window-left key did not return to the Changes panel"
	)

	local after = child.lua_get([[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return {
			panel_cursor = vim.api.nvim_win_get_cursor(panel.win),
			right_buf = panel.diff_view.right_buf,
			fragments = panel.diff_view.fragments,
		}
	end)()]])
	eq(after.panel_cursor, before.panel_cursor)
	eq(after.right_buf, before.right_buf)
	eq(after.fragments, before.fragments)
end

T["git: Branch diff panes move together"] = function()
	open_branch_diff()
	local state = view_state()
	type_and_wait(
		"<C-w>l",
		("vim.api.nvim_get_current_win() == %d"):format(state.left_win),
		"First native window-right key did not enter the left diff pane"
	)
	type_and_wait(
		"<C-w>l",
		("vim.api.nvim_get_current_win() == %d"):format(state.right_win),
		"Second native window-right key did not enter the right diff pane"
	)

	local line = state.right_cursor
	for _, movement in ipairs({
		{ "gg", 1 },
		{ "j" },
		{ "j" },
		{ "<C-d>" },
		{ "G", 37 },
		{ "k", 36 },
	}) do
		line = move_right_and_wait(movement[1], line, movement[2], true)
	end
	eq(line, 36)
end

T["git: Commit diff is read-only and navigable"] = function()
	open_commit_diff()
	local before = child.lua_get([[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return vim.api.nvim_buf_get_lines(panel.diff_view.right_buf, 0, -1, false)
	end)()]])

	local view = view_state()
	type_and_wait(
		"<C-l>",
		("vim.api.nvim_get_current_win() == %d"):format(view.left_win),
		"First window-right key did not enter the commit's left pane"
	)
	type_and_wait(
		"<C-l>",
		("vim.api.nvim_get_current_win() == %d"):format(view.right_win),
		"Second window-right key did not enter the commit's right pane"
	)
	local line = view.right_cursor
	line = move_right_and_wait("j", line)
	line = move_right_and_wait("G", line)
	move_right_and_wait("gg", line, 1)
	local edited, edit_error = pcall(function()
		child.type_keys("x")
	end)

	local state = child.lua_get([[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local view = panel.diff_view
		local highlighter = vim.treesitter.highlighter.active[view.right_buf]
		return {
			current = vim.api.nvim_get_current_win(),
			right_win = view.right_win,
			modifiable = vim.bo[view.right_buf].modifiable,
			lines = vim.api.nvim_buf_get_lines(view.right_buf, 0, -1, false),
			has_go_highlighter = highlighter ~= nil and highlighter.tree ~= nil,
		}
	end)()]])

	eq(state.has_go_highlighter, true)
	eq(edited, false)
	assert(tostring(edit_error):find("E21", 1, true), "editing did not fail as read-only")
	eq(state.current, state.right_win)
	eq(state.modifiable, false)
	eq(state.lines, before)
	local invoice = vim.fs.joinpath(root, "internal/billing/invoice.go")
	eq(child.lua_get("vim.bo[vim.fn.bufnr(...)].modified", { invoice }), false)
end

T["git: gf in a commit diff opens the working file"] = function()
	open_commit_diff()
	local view = view_state()
	child.api.nvim_set_current_win(view.right_win)
	child.api.nvim_win_set_cursor(view.right_win, { 18, 0 })

	child.type_keys("gf")

	local state = child.lua_get([[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return {
			active_tab = panel and panel.active_tab,
			current = vim.api.nvim_get_current_win(),
			name = vim.api.nvim_buf_get_name(0),
			line = vim.api.nvim_win_get_cursor(0)[1],
			panel_open = panel ~= nil and vim.api.nvim_win_is_valid(panel.win),
			diff_cleared = panel ~= nil and panel.diff_view == nil,
			has_diff = vim.iter(vim.api.nvim_list_wins()):any(function(win)
				return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "gleb-diff"
			end),
		}
	end)()]])
	eq(state.active_tab, "branch")
	eq(state.current, view.right_win)
	eq(vim.uv.fs_realpath(state.name), vim.uv.fs_realpath(vim.fs.joinpath(root, "internal/billing/invoice.go")))
	eq(state.line, 18)
	eq(state.panel_open, true)
	eq(state.diff_cleared, true)
	eq(state.has_diff, false)
end

return T
