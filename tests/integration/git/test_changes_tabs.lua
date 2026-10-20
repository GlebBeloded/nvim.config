local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_config)

local function toggle_changes()
	child.lua([[
		local catalog = require("gleb.actions").state.applicator.catalog
		local action = assert(catalog:get("changes.toggle"), "changes.toggle is not registered")
		action.run(require("gleb.actions.context").capture())
	]])
end

local function review_changes()
	child.lua([[
		local catalog = require("gleb.actions").state.applicator.catalog
		local action = assert(catalog:get("changes.review"), "changes.review is not registered")
		action.run(require("gleb.actions.context").capture())
	]])
end

---@param root string
local function report_pull_request(root)
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

---@param active string
---@param require_diff? boolean
local function wait_for_tab(active, require_diff)
	assert(
		child.wait(
			string.format(
				[[
		(function()
			local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return panel and panel.active_tab == %q and (%s or panel.diff_view ~= nil)
		end)()
	]],
				active,
				require_diff and "false" or "true"
			),
			3000
		),
		("Changes review did not open the %s tab"):format(active)
	)
end

local function panel_state()
	return child.lua_get([[
		(function()
			local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			if not panel then return {} end
			return {
				active = panel.active_tab,
				current = vim.api.nvim_get_current_win(),
				panel = panel.win,
				windows = #vim.api.nvim_tabpage_list_wins(0),
			}
		end)()
	]])
end

---@param fixture string
---@return string root
local function open_fixture(fixture)
	local root = F.copy(fixture, vim.fn.tempname() .. "/" .. fixture)
	local invoice = vim.fs.joinpath(root, "internal/billing/invoice.go")
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(invoice))
	toggle_changes()
	return root
end

---@return table
local function winbar()
	return child.lua_get([[
		(function()
			local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			if not view then return {} end
			local evaluated = vim.api.nvim_eval_statusline(vim.wo[view.win].winbar, {
				winid = view.win,
				highlights = true,
			})
			return {
				text = evaluated.str,
				highlights = vim.iter(evaluated.highlights):filter(function(item)
					return item.group ~= "StatusLine"
				end):map(function(item)
					return { start = item.start, group = item.group }
				end):totable(),
				winhighlight = vim.wo[view.win].winhighlight,
				first_line = vim.api.nvim_buf_get_lines(view.buf, 0, 1, false)[1],
			}
		end)()
	]])
end

---@return table
local function branch_panel()
	assert(
		child.wait(
			[[(function()
				local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return view and view.active_tab == "branch" and view.rows[8] ~= nil
			end)()]],
			3000
		),
		"Branch rows did not load"
	)
	return child.lua_get([[(function()
		local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local lines = vim.api.nvim_buf_get_lines(view.buf, 0, -1, false)
		local marks = {}
		for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(
			view.buf,
			require("gleb.git.changes.render").namespace,
			0,
			-1,
			{ details = true }
		)) do
			local details = mark[4]
			marks[#marks + 1] = {
				row = mark[2] + 1,
				group = details.hl_group,
				text = lines[mark[2] + 1]:sub(mark[3] + 1, details.end_col),
			}
		end
		local rows = vim.iter(view.rows):map(function(row)
			return {
				kind = row.kind,
				label = row.label,
				count = row.count,
				added = row.added,
				removed = row.removed,
			}
		end):totable()
		return { lines = lines, marks = marks, rows = rows }
	end)()]])
end

---@return table
local function current_panel()
	return child.lua_get([[(function()
		local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local rows = vim.iter(view.rows):map(function(row)
			return {
				id = row.id,
				kind = row.kind,
				label = row.label,
				depth = row.depth,
				added = row.added,
				removed = row.removed,
				hash = row.hash,
				age = row.age,
			}
		end):totable()
		return {
			active = view.active_tab,
			commit_view = view.commit_view,
			lines = vim.api.nvim_buf_get_lines(view.buf, 0, -1, false),
			rows = rows,
			cursor = vim.api.nvim_win_get_cursor(view.win)[1],
		}
	end)()]])
end

---@param id string
local function select_row(id)
	child.lua(
		[[(function(target)
		local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		for index, row in ipairs(view.rows) do
			if row.id == target then
				vim.api.nvim_win_set_cursor(view.win, { index, 0 })
				return
			end
		end
		error("row not found: " .. target)
	end)(...)]],
		{ id }
	)
end

---@return string root
local function open_branch_tab()
	child.wait_very_lazy()
	local root = F.copy("billing-branch", vim.fn.tempname() .. "/billing-branch")
	report_pull_request(root)
	local invoice = vim.fs.joinpath(root, "internal/billing/invoice.go")
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(invoice))
	child.lua([[require("gleb.git.changes.branch").now = function() return 1767315600 end]])
	review_changes()
	wait_for_tab("local", true)
	review_changes()
	branch_panel()
	return root
end

local function wait_for_commits()
	assert(
		child.wait(
			[[
		(function()
			local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return view.commit_view
				and view.rows[5]
				and view.rows[5].id == "branch:commit:e325463:file:internal/billing/invoice.go"
		end)()
	]],
			3000
		),
		"Branch commits did not load"
	)
end

---@param items table
---@param key string
---@return table
local function values_for(items, key)
	return vim.iter(items)
		:map(function(item)
			return item[key]
		end)
		:totable()
end

T["git: Changes tabs show Local and Branch on a feature branch"] = function()
	open_fixture("billing-branch")
	assert(
		child.wait(
			[[
		(function()
			local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return view and vim.wo[view.win].winbar:find("Branch 4", 1, true) ~= nil
		end)()
	]],
			3000
		),
		"Branch tab did not become available"
	)

	local bar = winbar()
	eq(bar.text, "  Local 3   Branch 4 ")
	eq(bar.highlights, {
		{ start = 1, group = "ChangesTabLocal" },
		{ start = 11, group = "ChangesTabInactive" },
	})
	assert(bar.winhighlight:find("WinBar:FileTreeNormal", 1, true), "WinBar does not use the panel background")
	assert(bar.winhighlight:find("WinBarNC:FileTreeNormal", 1, true), "WinBarNC does not use the panel background")
	assert(bar.first_line:find("Changes 2 files", 1, true), "first row is not the changes summary")
end

T["git: Changes tabs show only Local on the default branch"] = function()
	open_fixture("billing")
	assert(
		child.wait(
			[[
		(function()
			local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return view and vim.wo[view.win].winbar:find("Local 6", 1, true) ~= nil
		end)()
	]],
			3000
		),
		"Local tab did not draw"
	)

	local bar = winbar()
	eq(bar.text, "  Local 6 ")
	assert(not bar.text:find("Branch", 1, true), "default branch has a Branch tab")
end

T["git: Changes tab colours"] = function()
	child.api.nvim_set_hl(0, "ChangesTabLocal", { fg = "#000000" })
	child.api.nvim_exec_autocmds("ColorScheme", {})

	H.expect_hl_colors(child, "ChangesTabLocal", { fg = "#282828", bg = "#7daea3", bold = true })
	H.expect_hl_colors(child, "ChangesTabBranch", { fg = "#282828", bg = "#d3869b", bold = true })
	H.expect_hl_colors(child, "ChangesTabInactive", { fg = "#928374", bg = "#32302f" })
	H.expect_hl_colors(child, "ChangesBranchHeader", { fg = "#d3869b", bold = true })
	H.expect_hl_colors(child, "ChangesCommittedFile", { fg = "#d3869b" })
	H.expect_hl_colors(child, "ChangesCommitIcon", { fg = "#d3869b" })
	H.expect_hl_colors(child, "ChangesCommitHash", { fg = "#d8a657" })
end

T["git: Cmd+G cycles Local, Branch, then closes"] = function()
	local root = F.copy("billing-branch", vim.fn.tempname() .. "/billing-branch")
	local invoice = vim.fs.joinpath(root, "internal/billing/invoice.go")
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(invoice))

	review_changes()
	wait_for_tab("local", true)
	review_changes()
	wait_for_tab("branch", true)
	eq(panel_state().current, panel_state().panel)
	review_changes()
	eq(child.wait([[require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()] == nil]], 1000), true)
end

T["git: First review opens Branch when nothing is uncommitted"] = function()
	local root = F.copy("billing-branch", vim.fn.tempname() .. "/billing-branch")
	H.git(root, { "checkout", "--", "." })
	vim.fn.delete(vim.fs.joinpath(root, "notes.md"))
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("enew")

	review_changes()
	wait_for_tab("branch")
	review_changes()
	eq(child.wait([[require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()] == nil]], 1000), true)
end

T["git: Review on the default branch opens only Local"] = function()
	local root = F.copy("billing", vim.fn.tempname() .. "/billing")
	local invoice = vim.fs.joinpath(root, "internal/billing/invoice.go")
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(invoice))

	review_changes()
	wait_for_tab("local", true)
	review_changes()
	eq(child.wait([[require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()] == nil]], 1000), true)
end

T["git: Review from the diff window advances the tab"] = function()
	local root = F.copy("billing-branch", vim.fn.tempname() .. "/billing-branch")
	local invoice = vim.fs.joinpath(root, "internal/billing/invoice.go")
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(invoice))
	review_changes()
	wait_for_tab("local", true)
	child.lua([[
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		vim.api.nvim_set_current_win(panel.diff_view.right_win)
	]])
	local before = panel_state().windows

	review_changes()
	wait_for_tab("branch", true)
	local after = panel_state()
	eq(after.current, after.panel)
	eq(after.windows, before)
end

T["git: Branch tab lists the branch files"] = function()
	local root = F.copy("billing-branch", vim.fn.tempname() .. "/billing-branch")
	report_pull_request(root)
	local invoice = vim.fs.joinpath(root, "internal/billing/invoice.go")
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(invoice))

	review_changes()
	wait_for_tab("local", true)
	review_changes()
	local panel = branch_panel()

	eq(panel.rows, {
		{ kind = "header", label = "#482 feat/tax → main" },
		{ kind = "summary", label = "3 commits · merge-base 4ccefde" },
		{ kind = "blank", label = "" },
		{ kind = "directory", label = "internal/billing", count = 4 },
		{ kind = "file", label = "invoice.go", added = 11, removed = 2 },
		{ kind = "file", label = "invoice_test.go", added = 20, removed = 1 },
		{ kind = "file", label = "tax.go", added = 41, removed = 0 },
		{ kind = "file", label = "tax_test.go", added = 33, removed = 0 },
	})
end

T["git: Branch tab header without a pull request"] = function()
	local root = F.copy("billing-branch", vim.fn.tempname() .. "/billing-branch")
	local invoice = vim.fs.joinpath(root, "internal/billing/invoice.go")
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(invoice))

	review_changes()
	wait_for_tab("local", true)
	review_changes()
	local panel = branch_panel()

	eq(panel.lines[1], " feat/tax → main")
	eq(
		vim.iter(panel.marks)
			:filter(function(mark)
				return mark.group == "ChangesBranchHeader"
			end)
			:totable(),
		{}
	)
end

T["git: Branch tab colours committed files"] = function()
	local root = F.copy("billing-branch", vim.fn.tempname() .. "/billing-branch")
	report_pull_request(root)
	local invoice = vim.fs.joinpath(root, "internal/billing/invoice.go")
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(invoice))

	review_changes()
	wait_for_tab("local", true)
	review_changes()
	local panel = branch_panel()
	local committed = vim.iter(panel.marks)
		:filter(function(mark)
			return mark.group == "ChangesCommittedFile"
		end)
		:totable()

	eq(values_for(committed, "text"), { "invoice.go", "invoice_test.go", "tax.go", "tax_test.go" })
	eq(
		vim.iter(panel.marks)
			:filter(function(mark)
				return mark.group == "ChangesBranchHeader"
			end)
			:map(function(mark)
				return mark.text
			end)
			:totable(),
		{ " #482" }
	)
	eq(
		vim.iter(panel.marks)
			:filter(function(mark)
				return mark.group == "ChangesCheckbox"
			end)
			:totable(),
		{}
	)
end

T["git: c shows the branch commits"] = function()
	open_branch_tab()

	child.type_keys("c", "<Esc>")
	wait_for_commits()
	local panel = current_panel()

	eq(panel.rows, {
		{ id = "branch:header", kind = "header", label = "#482 feat/tax → main", depth = 0 },
		{ id = "branch:blank", kind = "blank", label = "", depth = 0 },
		{ id = "branch:all", kind = "all", label = "All changes", depth = 0 },
		{
			id = "branch:commit:e325463",
			kind = "commit",
			label = "wire tax into Total",
			depth = 0,
			hash = "e325463",
			age = "1h",
		},
		{
			id = "branch:commit:e325463:file:internal/billing/invoice.go",
			kind = "file",
			label = "invoice.go",
			depth = 1,
			added = 11,
			removed = 2,
		},
		{
			id = "branch:commit:07cb52e",
			kind = "commit",
			label = "add Rate and tax tests",
			depth = 0,
			hash = "07cb52e",
			age = "3h",
		},
		{
			id = "branch:commit:b5435c5",
			kind = "commit",
			label = "add tax.go",
			depth = 0,
			hash = "b5435c5",
			age = "1d",
		},
	})
	assert(panel.lines[4]:find("e325463 wire tax into Tot…", 1, true), "newest commit subject was not truncated")
	assert(panel.lines[4]:match("1h%s*$"), "newest commit age was not right-aligned")
	eq(panel.cursor, 5)
end

T["git: c again shows the branch files"] = function()
	open_branch_tab()
	child.type_keys("c", "<Esc>")
	wait_for_commits()

	child.type_keys("c", "<Esc>")
	assert(
		child.wait(
			[[require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()].commit_view == false]],
			3000
		)
	)
	local panel = current_panel()

	eq(values_for(panel.rows, "label"), {
		"#482 feat/tax → main",
		"3 commits · merge-base 4ccefde",
		"",
		"internal/billing",
		"invoice.go",
		"invoice_test.go",
		"tax.go",
		"tax_test.go",
	})
	eq(panel.rows[panel.cursor].label, "invoice.go")
end

T["git: Expanding a commit lists its files"] = function()
	open_branch_tab()
	child.type_keys("c", "<Esc>")
	wait_for_commits()
	select_row("branch:commit:07cb52e")

	child.type_keys("za")
	assert(
		child.wait(
			[[
		(function()
			local rows = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()].rows
			return vim.iter(rows):any(function(row)
				return row.id == "branch:commit:07cb52e:file:internal/billing/tax_test.go"
			end)
		end)()
	]],
			3000
		),
		"Commit files did not load"
	)
	local panel = current_panel()
	local commit
	for index, row in ipairs(panel.rows) do
		if row.id == "branch:commit:07cb52e" then
			commit = index
			break
		end
	end
	assert(commit, "Commit row disappeared")
	eq({ panel.rows[commit + 1], panel.rows[commit + 2] }, {
		{
			id = "branch:commit:07cb52e:file:internal/billing/invoice_test.go",
			kind = "file",
			label = "invoice_test.go",
			depth = 1,
			added = 20,
			removed = 1,
		},
		{
			id = "branch:commit:07cb52e:file:internal/billing/tax_test.go",
			kind = "file",
			label = "tax_test.go",
			depth = 1,
			added = 33,
			removed = 0,
		},
	})
end

T["git: Expanding All changes shows every branch file"] = function()
	open_branch_tab()
	child.type_keys("c", "<Esc>")
	wait_for_commits()
	select_row("branch:all")

	child.type_keys("za")
	local panel = current_panel()
	eq(vim.list_slice(values_for(panel.rows, "label"), 3, 7), {
		"All changes",
		"internal/billing",
		"invoice.go",
		"invoice_test.go",
		"tax.go",
	})
	eq(panel.rows[8].label, "tax_test.go")
	eq(panel.rows[4].depth, 1)
	eq(panel.rows[5].depth, 2)
end

T["git: c on the Local tab does nothing"] = function()
	child.wait_very_lazy()
	open_fixture("billing-branch")
	assert(
		child.wait(
			[[
		(function()
			local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return view and view.local_ready and #view.rows > 0
		end)()
	]],
			3000
		),
		"Local rows did not load"
	)
	local notifications = H.record_notify(child)
	local before = current_panel()

	child.type_keys("c", "<Esc>")
	local after = current_panel()

	eq(after.lines, before.lines)
	eq(after.active, "local")
	eq(notifications(), {})
end

return T
