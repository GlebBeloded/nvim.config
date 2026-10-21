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
						and (%q == "" or panel.diff_view.labels.right == %q)
				end)()]],
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
	wait_for_diff("branch", "e325463 · HEAD")
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

T["git: Changes Branch diff starts on the first change"] = function()
	open_branch_diff()

	local state = view_state()
	eq(state.current_win, state.panel_win)
	eq(state.right_cursor, 9)
	eq(state.left_cursor, 9)
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

T["git: Commit diff is read-only and navigable"] = function()
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
	local before = child.lua_get([[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return vim.api.nvim_buf_get_lines(panel.diff_view.right_buf, 0, -1, false)
	end)()]])

	child.type_keys("<C-l>")
	child.type_keys("<C-l>")
	child.type_keys("j")
	child.type_keys("G")
	child.type_keys("gg")
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

return T
