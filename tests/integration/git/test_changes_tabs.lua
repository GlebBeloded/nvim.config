local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_config)

---@return integer
local function async_timeout()
	return math.floor(5000 * H.load_factor())
end

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

---@param id string
local function run_action(id)
	child.lua(
		[[
		local id = ...
		local catalog = require("gleb.actions").state.applicator.catalog
		local action = assert(catalog:get(id), id .. " is not registered")
		action.run(require("gleb.actions.context").capture())
	]],
		{ id }
	)
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
			return panel and panel.tabs_ready and panel.active_tab == %q and (%s or panel.diff_view ~= nil)
		end)()
	]],
				active,
				require_diff and "false" or "true"
			),
			async_timeout()
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
			async_timeout()
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
			return view
				and view.commit_view
				and view.rows[5]
				and view.rows[5].id == "branch:commit:e325463:file:internal/billing/invoice.go"
		end)()
	]],
			async_timeout()
		),
		"Branch commits did not load"
	)
end

local function observe_diff_shows()
	child.lua([[
		BranchDiffShows = {}
		local diff = require("gleb.diff.view")
		local show = diff.show
		diff.show = function(win, spec)
			if spec.committed then
				BranchDiffShows[#BranchDiffShows + 1] = {
					relpath = spec.relpath,
					left = spec.left,
					right = spec.right,
					labels = spec.labels,
					committed = spec.committed,
					actionable = spec.actionable,
					right_buf = spec.right_buf,
				}
			end
			return show(win, spec)
		end
	]])
end

---@param path string
---@param right_label? string
local function wait_for_branch_diff(path, right_label)
	assert(
		child.wait(
			([[(function()
				local shows = BranchDiffShows or {}
				local shown = shows[#shows]
				return shown
					and shown.relpath == %q
					and shown.committed == true
					and (%q == "" or shown.labels.right == %q)
			end)()]]):format(path, right_label or "", right_label or ""),
			async_timeout()
		),
		"Branch diff did not load: " .. path
	)
end

---@param root string
---@param rev_path string
---@return string[]
local function git_lines(root, rev_path)
	local output = H.git(root, { "show", rev_path })
	return vim.split(output:gsub("\n$", ""), "\n", { plain = true })
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

---@param row integer
---@param count? integer
---@return string
local function screen_line(row, count)
	local cells = H.screen_rows(child, row, row).text[1]
	return table.concat(count and vim.list_slice(cells, 1, count) or cells)
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
			async_timeout()
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
			async_timeout()
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
			async_timeout()
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
			async_timeout()
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
			async_timeout()
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

T["git: Branch tab shows the merge-base diff"] = function()
	observe_diff_shows()
	local root = open_branch_tab()
	select_row("branch:file:internal/billing/invoice.go")
	wait_for_branch_diff("internal/billing/invoice.go")

	local shown = child.lua_get("BranchDiffShows[#BranchDiffShows]")
	eq(shown.left, git_lines(root, "4ccefde:internal/billing/invoice.go"))
	eq(shown.right, git_lines(root, "HEAD:internal/billing/invoice.go"))
	eq({ shown.labels, shown.committed, shown.actionable }, {
		{ left = "4ccefde · main", right = "e325463 · HEAD" },
		true,
		false,
	})
	eq(shown.right_buf, nil)
	local buffers = child.lua_get([=[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return {
			left = vim.api.nvim_buf_get_name(panel.diff_view.left_buf),
			right = vim.api.nvim_buf_get_name(panel.diff_view.right_buf),
			working = vim.fs.joinpath(panel.root, "internal/billing/invoice.go"),
		}
	end)()]=])
	assert(buffers.left ~= buffers.working and buffers.right ~= buffers.working, "Branch diff used the working buffer")
end

T["git: Branch tab shows a commit's diff"] = function()
	observe_diff_shows()
	local root = open_branch_tab()
	child.type_keys("c", "<Esc>")
	wait_for_commits()
	select_row("branch:commit:e325463:file:internal/billing/invoice.go")
	wait_for_branch_diff("internal/billing/invoice.go", "e325463 · wire tax into Total")

	local shown = child.lua_get("BranchDiffShows[#BranchDiffShows]")
	eq(shown.left, git_lines(root, "e325463^:internal/billing/invoice.go"))
	eq(shown.right, git_lines(root, "e325463:internal/billing/invoice.go"))
	eq(shown.labels, { left = "07cb52e · parent", right = "e325463 · wire tax into Total" })
end

T["git: Branch tab shows an added file"] = function()
	observe_diff_shows()
	local root = open_branch_tab()
	select_row("branch:file:internal/billing/tax.go")
	wait_for_branch_diff("internal/billing/tax.go")

	local shown = child.lua_get("BranchDiffShows[#BranchDiffShows]")
	eq(shown.left, {})
	eq(shown.right, git_lines(root, "HEAD:internal/billing/tax.go"))
end

T["git: Branch tab ]f steps through the branch files"] = function()
	observe_diff_shows()
	open_branch_tab()
	select_row("branch:file:internal/billing/invoice.go")
	wait_for_branch_diff("internal/billing/invoice.go")
	child.lua([[
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		vim.api.nvim_set_current_win(panel.diff_view.right_win)
	]])

	for _, path in ipairs({
		"internal/billing/invoice_test.go",
		"internal/billing/tax.go",
		"internal/billing/tax_test.go",
	}) do
		child.type_keys("]f")
		wait_for_branch_diff(path)
	end

	local result = child.lua_get([=[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return {
			shown = vim.iter(BranchDiffShows):map(function(item) return item.relpath end):totable(),
			row = panel.rows[vim.api.nvim_win_get_cursor(panel.win)[1]].path,
		}
	end)()]=])
	eq(result, {
		shown = {
			"internal/billing/invoice.go",
			"internal/billing/invoice_test.go",
			"internal/billing/tax.go",
			"internal/billing/tax_test.go",
		},
		row = "internal/billing/tax_test.go",
	})
end

T["git: Branch tab Enter opens the working file"] = function()
	observe_diff_shows()
	local root = open_branch_tab()
	select_row("branch:file:internal/billing/invoice.go")
	wait_for_branch_diff("internal/billing/invoice.go")
	select_row("branch:file:internal/billing/tax.go")
	wait_for_branch_diff("internal/billing/tax.go")

	child.type_keys("<CR>")
	local expected_path = vim.fs.joinpath(assert(vim.uv.fs_realpath(root)), "internal/billing/tax.go")
	assert(
		child.wait(
			([[(function()
				if vim.api.nvim_buf_get_name(0) ~= %q then return false end
				return vim.iter(vim.api.nvim_tabpage_list_wins(0)):all(function(win)
					return vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "gleb-diff"
				end)
			end)()]]):format(expected_path),
			async_timeout()
		),
		"Branch Enter did not open the working file"
	)
	local result = child.lua_get([=[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local diff_windows = vim.iter(vim.api.nvim_tabpage_list_wins(0)):filter(function(win)
			return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "gleb-diff"
		end):totable()
		return {
			current = vim.api.nvim_buf_get_name(0),
			panel_open = vim.api.nvim_win_is_valid(panel.win),
			active = panel.active_tab,
			diff_windows = #diff_windows,
		}
	end)()]=])
	eq(result, {
		current = expected_path,
		panel_open = true,
		active = "branch",
		diff_windows = 0,
	})
end

T["git: Branch tab ignores staging keys"] = function()
	local root = open_branch_tab()
	select_row("branch:file:internal/billing/invoice.go")
	local paths = {
		"internal/billing/invoice.go",
		"web/src/price.ts",
		"notes.md",
	}
	local before = vim.iter(paths)
		:map(function(path)
			return vim.fn.readfile(vim.fs.joinpath(root, path))
		end)
		:totable()
	local cached = H.git(root, { "diff", "--cached", "--name-only" })
	child.lua([[
		BranchStagingPrompts = 0
		vim.ui.input = function()
			BranchStagingPrompts = BranchStagingPrompts + 1
		end
	]])

	child.type_keys("<Space>", "A", "X")
	child.lua([[
		vim.wait(1000, function()
			local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return BranchStagingPrompts > 0 or vim.iter(panel.local_rows):any(function(row)
				return row.kind == "file" and row.staged
			end)
		end, 10)
	]])

	eq(H.git(root, { "diff", "--cached", "--name-only" }), cached)
	eq(child.lua_get("BranchStagingPrompts"), 0)
	eq(
		vim.iter(paths)
			:map(function(path)
				return vim.fn.readfile(vim.fs.joinpath(root, path))
			end)
			:totable(),
		before
	)
end

T["git: Branch tab refreshes after a commit"] = function()
	local root = open_branch_tab()
	select_row("branch:file:internal/billing/invoice_test.go")
	local before = child.lua_get([=[(function()
		local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return {
			selected = view.rows[vim.api.nvim_win_get_cursor(view.win)[1]].id,
			folded = view.tree.folds["branch:directory:internal/billing"],
		}
	end)()]=])

	H.git(root, { "add", "notes.md" })
	H.git(root, { "commit", "-q", "-m", "notes" })
	child.cmd("checktime")

	assert(
		child.wait(
			[[(function()
				local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				local bar = view and vim.wo[view.win].winbar or ""
				if not bar:find("Local 2", 1, true) or not bar:find("Branch 5", 1, true) then
					return false
				end
				local summary
				local has_notes = false
				for _, row in ipairs(view.rows) do
					if row.kind == "summary" then summary = row.label end
					if row.kind == "file" and row.path == "notes.md" then has_notes = true end
				end
				return summary == "4 commits · merge-base 4ccefde" and has_notes
			end)()]],
			async_timeout()
		),
		"Branch tab did not refresh after the commit"
	)
	local after = child.lua_get([=[(function()
		local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return {
			selected = view.rows[vim.api.nvim_win_get_cursor(view.win)[1]].id,
			folded = view.tree.folds["branch:directory:internal/billing"],
		}
	end)()]=])
	eq(after, before)
end

T["git: Tab actions are in the catalog"] = function()
	eq(
		child.lua_get([[
			(function()
				local actions = require("gleb.actions")
				local catalog = actions.state.applicator.catalog
				local result = {}
				for _, id in ipairs({
					"changes.show_local",
					"changes.show_branch",
					"changes.show_branch_commits",
					"changes.toggle_commits",
				}) do
					local action = assert(catalog:get(id), id .. " is not registered")
					result[id] = {
						title = action.title,
						category = action.category,
						ft = action.ft,
						keys = actions.state.store.last_good[id],
					}
				end
				return result
			end)()
		]]),
		{
			["changes.show_local"] = { title = "Show Local Changes", category = "View | Tool Windows" },
			["changes.show_branch"] = { title = "Show Branch Changes", category = "View | Tool Windows" },
			["changes.show_branch_commits"] = {
				title = "Show Branch Commits",
				category = "View | Tool Windows",
			},
			["changes.toggle_commits"] = {
				title = "Toggle Commits",
				category = "Changes",
				ft = "gleb-changes",
				keys = { "c" },
			},
		}
	)
end

T["git: Show Branch Commits opens the commit view"] = function()
	child.wait_very_lazy()
	local root = F.copy("billing-branch", vim.fn.tempname() .. "/billing-branch")
	report_pull_request(root)
	local invoice = vim.fs.joinpath(root, "internal/billing/invoice.go")
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(invoice))
	child.lua([[require("gleb.git.changes.branch").now = function() return 1767315600 end]])

	run_action("changes.show_branch_commits")
	wait_for_commits()
	local panel = current_panel()

	eq(panel.active, "branch")
	eq(panel.commit_view, true)
	eq(panel.rows[3].id, "branch:all")
	eq(panel_state().current, panel_state().panel)
end

T["git: Show Branch on the default branch"] = function()
	child.wait_very_lazy()
	open_fixture("billing")
	wait_for_tab("local")
	local notifications = H.record_notify(child)
	local before = current_panel()

	run_action("changes.show_branch")
	local after = current_panel()

	eq(notifications(), { { msg = "No branch changes on main", level = vim.log.levels.WARN } })
	eq(after.active, "local")
	eq(after.lines, before.lines)
end

T["git: Toggle reopens the last tab"] = function()
	open_branch_tab()
	child.type_keys("c", "<Esc>")
	wait_for_commits()

	child.type_keys("q", "<Esc>")
	eq(child.wait([[require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()] == nil]], 1000), true)
	toggle_changes()
	wait_for_commits()
	local panel = current_panel()

	eq(panel.active, "branch")
	eq(panel.rows[3].id, "branch:all")
end

T["git: Review starts the cycle again after a close"] = function()
	open_branch_tab()

	child.type_keys("q", "<Esc>")
	eq(child.wait([[require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()] == nil]], 1000), true)
	review_changes()
	wait_for_tab("local")

	eq(current_panel().active, "local")
end

T["git: Branch tab hint names the commit view key"] = function()
	child.o.lines = 30
	child.o.columns = 100
	open_branch_tab()

	eq(screen_line(28, 35), ("─"):rep(35))
	eq(screen_line(29, 35), "           Commits c · Next tab ⌘G ")

	child.type_keys("c", "<Esc>")
	wait_for_commits()
	eq(screen_line(29, 35), "             Files c · Next tab ⌘G ")
end

T["git: Branch tab hint follows a reassigned key"] = function()
	child.wait_very_lazy()
	child.o.lines = 30
	child.o.columns = 100
	child.lua([[
		local actions = require("gleb.actions")
		local shortcuts = vim.deepcopy(actions.state.store.last_good)
		shortcuts["changes.toggle_commits"] = { "C" }
		local path = vim.fn.tempname()
		vim.fn.writefile({ vim.json.encode(shortcuts) }, path)
		actions.state.store.path = path
		assert(actions.apply())
	]])
	open_branch_tab()

	eq(screen_line(29, 35), "           Commits C · Next tab ⌘G ")
	child.type_keys("C", "<Esc>")
	wait_for_commits()
	eq(current_panel().commit_view, true)
end

T["git: Branch tab keeps the last row above the hint"] = function()
	child.o.lines = 12
	child.o.columns = 100
	open_branch_tab()

	child.type_keys("G", "<Esc>")
	local rows = H.screen_rows(child, 1, 12).text
	local rule
	local last
	for index, cells in ipairs(rows) do
		local line = table.concat(vim.list_slice(cells, 1, 35))
		if line == ("─"):rep(35) then
			rule = index
		elseif line:find("tax_test.go", 1, true) then
			last = index
		end
	end
	assert(rule, "Branch hint rule was not drawn")
	assert(last and last < rule, "last Branch row was not visible above the hint")
end

T["git: Local tab has no hint row"] = function()
	child.o.lines = 30
	child.o.columns = 100
	open_fixture("billing-branch")

	assert(not screen_line(28, 35):find("─", 1, true), "Local tab drew the Branch hint rule")
	assert(not screen_line(29, 35):find("Next tab", 1, true), "Local tab drew the Branch hint")
end

return T
