local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")
local pr482 = require("tests.fixtures.gh.pr482")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_config)

---@return integer
local function async_timeout()
	return math.floor(5000 * H.load_factor())
end

---@param id string
local function run_action(id)
	child.lua(
		[[local id = ...
		local action = assert(require("gleb.actions").state.applicator.catalog:get(id), id .. " is not registered")
		action.run(require("gleb.actions.context").capture())]],
		{ id }
	)
end

---@param with_pr boolean
---@param mutate? fun(files: table<string, string>)
---@return string root
local function open_billing_branch(with_pr, mutate)
	child.wait_very_lazy()
	local root, manifest = F.copy("billing-branch", vim.fn.tempname() .. "/billing-branch")
	root = vim.fs.normalize(vim.fn.resolve(root))
	local gh_dir = vim.fn.tempname()
	local files = pr482(manifest)
	if not with_pr then
		files["pr.json"] = nil
	end
	if mutate then
		mutate(files)
	end
	H.write_files(gh_dir, files)
	child.lua([[vim.env.FAKE_GH_DIR = ...]], { gh_dir })
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice.go")))
	child.lua(
		[[BaseDone = false
		require("gleb.git.base").resolve(..., function() BaseDone = true end)]],
		{ root }
	)
	assert(child.wait("BaseDone == true", async_timeout()), "Pull request metadata did not resolve")
	if with_pr then
		child.lua(
			[[ThreadsDone = false
			vim.api.nvim_create_autocmd("User", {
				pattern = "GlebPrThreads",
				once = true,
				callback = function() ThreadsDone = true end,
			})
			require("gleb.pr").refresh(...)]],
			{ root }
		)
		assert(child.wait("ThreadsDone == true", async_timeout()), "Pull request threads did not load")
	end
	return root
end

---@param active string
---@param has_diff boolean
local function wait_for_tab(active, has_diff)
	assert(
		child.wait(
			([[(function()
				local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return panel
					and panel.tabs_ready
					and panel.active_tab == %q
					and (panel.diff_view ~= nil) == %s
			end)()]]):format(active, tostring(has_diff)),
			async_timeout()
		),
		("Changes review did not open the %s tab"):format(active)
	)
end

local function open_comments()
	open_billing_branch(true)
	run_action("changes.show_comments")
	wait_for_tab("comments", false)
end

---@return string[]
local function panel_lines()
	return child.lua_get([[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return vim.api.nvim_buf_get_lines(panel.buf, 0, -1, false)
	end)()]])
end

---@param needle string
local function select_row(needle)
	child.lua(
		[[(function(needle)
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		for index, line in ipairs(vim.api.nvim_buf_get_lines(panel.buf, 0, -1, false)) do
			if line:find(needle, 1, true) then
				vim.api.nvim_win_set_cursor(panel.win, { index, 0 })
				return
			end
		end
		error("row not found: " .. needle)
	end)(...)]],
		{ needle }
	)
end

T["pr: Comments tab follows Branch with a pull request"] = function()
	open_billing_branch(true)
	run_action("changes.toggle")
	assert(
		child.wait(
			[[(function()
				local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return panel and panel.tabs_ready and vim.api.nvim_eval_statusline(
					vim.wo[panel.win].winbar,
					{ winid = panel.win, highlights = true }
				).str == "  Local 3   Branch 4   Comments 3 "
			end)()]],
			async_timeout()
		),
		"Comments tab did not follow Branch"
	)
	local comments = child.lua_get([[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local evaluated = vim.api.nvim_eval_statusline(vim.wo[panel.win].winbar, {
			winid = panel.win,
			highlights = true,
		})
		return vim.iter(evaluated.highlights):find(function(item)
			return item.start == 22
		end).group
	end)()]])
	eq(comments, "ChangesTabInactive")
end

T["pr: Cmd+G cycles Local, Branch, Comments, then closes"] = function()
	open_billing_branch(true)
	run_action("changes.review")
	wait_for_tab("local", true)
	run_action("changes.review")
	wait_for_tab("branch", true)
	run_action("changes.review")
	wait_for_tab("comments", false)
	eq(
		child.lua_get([[(function()
			local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return {
				current = vim.api.nvim_get_current_win() == panel.win,
				filetype = vim.bo[vim.api.nvim_win_get_buf(panel.win)].filetype,
				diff_windows = #vim.tbl_filter(function(win)
					return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "gleb-diff"
				end, vim.api.nvim_tabpage_list_wins(0)),
			}
		end)()]]),
		{ current = true, filetype = "gleb-changes", diff_windows = 0 }
	)
	run_action("changes.review")
	assert(
		child.wait(
			[[require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()] == nil]],
			async_timeout()
		),
		"Changes panel did not close after Comments"
	)
end

T["pr: Show Pull Request Comments opens the Comments tab"] = function()
	open_billing_branch(true)
	run_action("changes.show_comments")
	wait_for_tab("comments", false)
	eq(
		child.lua_get([[(function()
			local actions = require("gleb.actions")
			local action = actions.state.applicator.catalog:get("changes.show_comments")
			local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return {
				current = vim.api.nvim_get_current_win() == panel.win,
				title = action and action.title,
				category = action and action.category,
				keys = actions.state.store.last_good["changes.show_comments"],
			}
		end)()]]),
		{
			current = true,
			title = "Show Pull Request Comments",
			category = "View | Tool Windows",
		}
	)
end

T["pr: Show Pull Request Comments without a pull request"] = function()
	open_billing_branch(false)
	local notifications = H.record_notify(child)
	run_action("changes.show_comments")
	assert(child.wait("#Notifications == 1", async_timeout()), "Missing no-pull-request warning")
	eq(notifications(), { { msg = "No pull request for feat/tax", level = vim.log.levels.WARN } })
	eq(child.lua_get([[require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()] == nil]]), true)
end

T["pr: Comments tab lists the threads by file"] = function()
	open_comments()
	local lines = panel_lines()
	eq(#lines, 10)
	for index, expected in ipairs({
		"#482 feat/tax → main",
		"3 open · 1 resolved",
		"",
		"internal/billing 3",
		"invoice.go 2",
		":13 ivan.p Rate or *Rate…",
		":22 maria.k Should a nil…",
		":11 ivan.p Should ID stay…",
		"tax.go 1",
		":18 maria.k Round… outdated",
	}) do
		eq(lines[index]:find(expected, 1, true) ~= nil, true)
	end
end

T["pr: Comments tab row colours"] = function()
	open_comments()
	select_row(":22")
	local groups = child.lua_get([[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local ns = require("gleb.git.changes.render").namespace
		local result = {}
		for _, row in ipairs({ 7, 8, 10 }) do
			for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(panel.buf, ns, { row - 1, 0 }, { row - 1, -1 }, { details = true })) do
				result[#result + 1] = mark[4].hl_group
			end
		end
		return result
	end)()]])
	for _, group in ipairs({
		"PrPeekIcon",
		"PrPeekMeta",
		"PrPeekAuthor",
		"PrPeek",
		"PrThreadResolved",
		"PrThreadOutdated",
	}) do
		eq(vim.tbl_contains(groups, group), true)
	end
end

T["pr: Comments tab folds a file"] = function()
	open_comments()
	select_row(":22")
	child.type_keys("h")
	assert(
		child.wait(
			[[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return not table.concat(vim.api.nvim_buf_get_lines(panel.buf, 0, -1, false), "\n"):find(":22", 1, true)
	end)()]],
			1000
		),
		child.lua_get([[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local id = require("gleb.ui.tree.view").selected_id(panel.tree)
		return vim.inspect({ id = id, parent = panel.tree.parents[id], folds = panel.tree.folds, map = vim.fn.maparg("h", "n") })
	end)()]])
	)
	local lines = panel_lines()
	eq(table.concat(lines, "\n"):find(":13", 1, true), nil)
	eq(table.concat(lines, "\n"):find(":22", 1, true), nil)
	eq(table.concat(lines, "\n"):find(":11", 1, true), nil)
	eq(lines[child.lua_get("vim.api.nvim_win_get_cursor(0)[1]")]:find("invoice.go", 1, true) ~= nil, true)
end

T["pr: Comments tab shows a fetch failure"] = function()
	local root = open_billing_branch(true, function(files)
		files["ReviewThreads.json.code"] = "1"
		files["ReviewThreads.json.stderr"] = "error connecting to pgw.dev"
	end)
	run_action("changes.show_comments")
	wait_for_tab("comments", false)
	assert(
		child.wait(
			([[(function(root)
				local pr = require("gleb.pr")
				return pr.state.in_flight[root] == nil
					and pr.state.failures[root] == "PR comments unavailable: error connecting to pgw.dev"
			end)(%q)]]):format(root),
			async_timeout()
		),
		"failed thread fetch did not finish"
	)
	eq(panel_lines()[2], " PR comments unavailable: error connecting to pgw.dev")
	run_action("changes.show_local")
	assert(
		child.wait(
			[[require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()].active_tab == "local"]]
		)
	)
	eq(table.concat(panel_lines(), "\n"):find("invoice.go", 1, true) ~= nil, true)
	run_action("changes.show_branch")
	assert(
		child.wait(
			[[require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()].active_tab == "branch"]]
		)
	)
	eq(table.concat(panel_lines(), "\n"):find("invoice.go", 1, true) ~= nil, true)
end

T["pr: Selecting a thread shows its line"] = function()
	local root = open_billing_branch(true)
	run_action("changes.show_comments")
	wait_for_tab("comments", false)
	select_row(":22")
	assert(
		child.wait(
			([[(function(root)
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return vim.api.nvim_win_get_cursor(panel.editor_win)[1] == 22
			and vim.fs.normalize(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(panel.editor_win)))
				== vim.fs.joinpath(%q, "internal/billing/invoice.go")
	end)(%q)]]):format(root, root),
			async_timeout()
		),
		"thread preview did not reach line 22"
	)
	eq(child.lua_get([[vim.bo.filetype]]), "gleb-changes")
end

T["pr: Enter on a thread opens its line"] = function()
	local root = open_billing_branch(true)
	run_action("changes.show_comments")
	wait_for_tab("comments", false)
	select_row(":22")
	child.type_keys("<CR>")
	assert(
		child.wait(
			([[(function(root)
				local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				local thread = require("gleb.pr.thread_window").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return thread
					and thread.thread.id == "PRRT_t1"
					and vim.api.nvim_get_current_win() == thread.reply_win
					and vim.api.nvim_win_get_cursor(panel.editor_win)[1] == 22
					and vim.fs.normalize(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(panel.editor_win)))
						== vim.fs.joinpath(%q, "internal/billing/invoice.go")
			end)(%q)]]):format(root, root),
			async_timeout()
		),
		"Enter did not open the mapped thread window after navigating to its line"
	)
	eq(
		child.lua_get([[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return { open = vim.api.nvim_win_is_valid(panel.win), tab = panel.active_tab }
	end)()]]),
		{ open = true, tab = "comments" }
	)
end

T["pr: Selecting an unmapped thread shows its diff hunk"] = function()
	local diff_hunk = "@@ -9,1 +9,0 @@\n-removed line"
	open_billing_branch(true, function(files)
		local response = vim.json.decode(files["ReviewThreads.json"])
		table.insert(response.data.repository.pullRequest.reviewThreads.nodes, 1, {
			id = "PRRT_left",
			isResolved = false,
			isOutdated = false,
			path = "internal/billing/invoice.go",
			line = 9,
			originalLine = 9,
			startLine = vim.NIL,
			originalStartLine = vim.NIL,
			diffSide = "LEFT",
			subjectType = "LINE",
			resolvedBy = vim.NIL,
			viewerCanReply = true,
			viewerCanResolve = true,
			viewerCanUnresolve = false,
			comments = {
				pageInfo = { hasNextPage = false, endCursor = vim.NIL },
				nodes = {
					{
						id = "PRRRC_left",
						author = { login = "reviewer" },
						body = "Removed line",
						createdAt = "2026-01-01T00:00:00Z",
						url = "https://example.test/left",
						diffHunk = diff_hunk,
						originalCommit = { oid = "left" },
						replyTo = vim.NIL,
					},
				},
			},
		})
		files["ReviewThreads.json"] = vim.json.encode(response)
	end)
	run_action("changes.show_comments")
	wait_for_tab("comments", false)
	select_row(":9")
	assert(
		child.wait(
			[[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local buf = vim.api.nvim_win_get_buf(panel.editor_win)
		return vim.bo[buf].filetype == "diff" and not vim.bo[buf].modifiable
	end)()]],
			async_timeout()
		),
		"unmapped hunk preview did not open"
	)
	local lines = child.lua_get([[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(panel.editor_win), 0, -1, false)
	end)()]])
	eq(lines, vim.split(diff_hunk, "\n", { plain = true }))
end

T["pr: Enter on an unmapped thread shows its diff hunk"] = function()
	local diff_hunk
	open_billing_branch(true, function(files)
		local response = vim.json.decode(files["ReviewThreads.json"])
		local thread = response.data.repository.pullRequest.reviewThreads.nodes[1]
		diff_hunk = thread.comments.nodes[1].diffHunk
	end)
	run_action("changes.show_comments")
	wait_for_tab("comments", false)
	child.lua([[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		vim.api.nvim_buf_set_lines(vim.api.nvim_win_get_buf(panel.editor_win), 21, 22, false, {})
	end)()]])
	select_row(":22")
	child.type_keys("<CR>")
	assert(
		child.wait(
			[[(function()
				local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				local hunk_buf = vim.api.nvim_win_get_buf(panel.editor_win)
				local thread = require("gleb.pr.thread_window").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return thread
					and thread.thread.id == "PRRT_t1"
					and vim.api.nvim_get_current_win() == thread.reply_win
					and vim.bo[hunk_buf].filetype == "diff"
					and not vim.bo[hunk_buf].modifiable
			end)()]],
			async_timeout()
		),
		"Enter did not open the unmapped thread window after showing its hunk"
	)
	eq(
		child.lua_get([[require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()].active_tab]]),
		"comments"
	)
	eq(
		child.lua_get([[(function()
			local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			local hunk_buf = vim.api.nvim_win_get_buf(panel.editor_win)
			return vim.api.nvim_buf_get_lines(hunk_buf, 0, -1, false)
		end)()]]),
		vim.split(diff_hunk, "\n", { plain = true })
	)
	eq(
		child.lua_get([[(function()
			local thread = require("gleb.pr.thread_window").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return vim.api.nvim_buf_get_lines(thread.messages_buf, 0, 3, false)
		end)()]]),
		(function()
			local lines = vim.split(diff_hunk, "\n", { plain = true })
			return vim.list_slice(lines, math.max(1, #lines - 2), #lines)
		end)()
	)
end

return T
