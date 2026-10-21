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

local function review_changes()
	child.lua([[
		local action = assert(require("gleb.actions").state.applicator.catalog:get("changes.review"))
		action.run(require("gleb.actions.context").capture())
	]])
end

---@param active string
local function wait_for_tab(active)
	assert(
		child.wait(
			([[(function()
				local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return panel and panel.tabs_ready and panel.active_tab == %q and panel.diff_view ~= nil
			end)()]]):format(active),
			async_timeout()
		),
		("Changes review did not open the %s tab"):format(active)
	)
end

local function open_branch_files()
	child.wait_very_lazy()
	local root = F.copy("billing-branch", vim.fn.tempname() .. "/billing-branch")
	report_pull_request(root)
	local invoice = vim.fs.joinpath(root, "internal/billing/invoice.go")
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(invoice))
	child.lua([[require("gleb.git.changes.branch").now = function() return 1767315600 end]])
	review_changes()
	wait_for_tab("local")
	review_changes()
	wait_for_tab("branch")
end

local function open_branch_commits()
	open_branch_files()
	child.type_keys("c", "<Esc>")
	assert(
		child.wait(
			[[(function()
				local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return panel and panel.commit_view and panel.rows[5]
					and panel.rows[5].id == "branch:commit:e325463:file:internal/billing/invoice.go"
			end)()]],
			async_timeout()
		),
		"Branch commits did not load"
	)
end

---@param id string
local function select_row(id)
	child.lua(
		[[(function(target)
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		for index, row in ipairs(panel.rows) do
			if row.id == target then
				vim.api.nvim_win_set_cursor(panel.win, { index, 0 })
				return
			end
		end
		error("row not found: " .. target)
	end)(...)]],
		{ id }
	)
end

local function open_commit_url_picker()
	child.type_keys("<M-A>")
	assert(child.wait([[require("mini.pick").is_picker_active()]], async_timeout()), "Find Action did not open")
	child.type_keys("commit url")
end

---@param keys? string
local function open_file_url_picker(keys)
	child.type_keys(keys or "<M-A>")
	assert(child.wait([[require("mini.pick").is_picker_active()]], async_timeout()), "Find Action did not open")
	child.type_keys("file url")
	assert(
		child.wait([[#require("mini.pick").get_picker_matches().all == 1]], async_timeout()),
		"File URL did not match"
	)
end

---@param files table<string, string>
---@param remote string
---@param branch string
---@param path string
local function open_repo_file(files, remote, branch, path)
	local root = H.git_repo(files, { remote = remote })
	H.git(root, { "switch", "-q", "-c", branch })
	child.wait_very_lazy()
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, path)))
end

---@param expected string
local function choose_file_url(expected)
	child.fn.setreg("+", "unchanged")
	open_file_url_picker()
	child.type_keys("<CR>")
	assert(child.wait(([[vim.fn.getreg("+") == %q]]):format(expected), async_timeout()), "File URL was not copied")
	eq(child.fn.getreg("+"), expected)
end

---@param expected string
local function choose_unavailable_file_url(expected)
	local notifications = H.record_notify(child)
	child.fn.setreg("+", "unchanged")
	open_file_url_picker()
	child.type_keys("<CR>")
	assert(child.wait([[#Notifications == 1]], async_timeout()), "File URL error was not reported")
	eq(child.fn.getreg("+"), "unchanged")
	eq(notifications(), { { msg = expected, level = vim.log.levels.ERROR } })
end

---@return string[]
local function matched_action_ids()
	return child.lua_get([[
		vim.iter(require("mini.pick").get_picker_matches().all)
			:filter(function(row) return row.action ~= nil end)
			:map(function(row) return row.action.id end)
			:totable()
	]])
end

---@return table
local function matched_file_url_row()
	return child.lua_get([[(function()
		local row = require("mini.pick").get_picker_matches().all[1]
		return { id = row.action.id, title = row.text, category = row.category, shortcut = row.secondary }
	end)()]])
end

T["git: Copy File URL remains listed with and without a shortcut"] = function()
	child.wait_very_lazy()
	child.lua([[
		local actions = require("gleb.actions")
		actions.state.store.path = vim.fn.tempname()
		local shortcuts = vim.deepcopy(actions.state.store.last_good)
		shortcuts["git.copy_file_url"] = nil
		assert(actions.state.store:save(shortcuts))
		actions.state.applicator:apply(actions.state.store.last_good)
	]])
	local path = child.lua_get([[vim.fn.tempname()]])
	child.lua([[vim.fn.writefile({ "one", "two", "three" }, ...)]], { path })
	child.cmd("edit " .. vim.fn.fnameescape(path))

	open_file_url_picker()
	eq(matched_file_url_row(), { id = "git.copy_file_url", title = "Copy File URL", category = "Git" })
	child.type_keys("<Esc>")

	open_file_url_picker("vjj<M-A>")
	eq(matched_file_url_row(), { id = "git.copy_file_url", title = "Copy File URL", category = "Git" })
	child.type_keys("<Esc>")

	open_file_url_picker()
	child.type_keys("<M-}>", "<F23>", "<CR>")
	assert(
		child.wait(
			[[require("gleb.actions").state.store.last_good["git.copy_file_url"][1] == "<F23>"]],
			async_timeout()
		),
		"File URL shortcut was not assigned"
	)
	eq(matched_file_url_row(), {
		id = "git.copy_file_url",
		title = "Copy File URL",
		category = "Git",
		shortcut = "<F23>",
	})
	child.type_keys("<Esc>")

	open_file_url_picker("vjj<M-A>")
	eq(matched_file_url_row(), {
		id = "git.copy_file_url",
		title = "Copy File URL",
		category = "Git",
		shortcut = "<F23>",
	})
end

T["git: github.com current-line branch URL is copied"] = function()
	open_repo_file({ ["a.txt"] = "one\ntwo\nthree" }, "git@github.com:owner/repo.git", "feature/share", "a.txt")
	child.api.nvim_win_set_cursor(0, { 2, 0 })

	choose_file_url("https://github.com/owner/repo/blob/feature/share/a.txt#L2")
end

T["git: Enterprise GitHub current-line branch URL is copied"] = function()
	open_repo_file(
		{ ["internal/billing/invoice.go"] = "1\n2\n3\n4\n5\n6\n7\n8\n9\n10" },
		"git@pgw.dev:finteqhub/billing.git",
		"feat/tax",
		"internal/billing/invoice.go"
	)
	child.api.nvim_win_set_cursor(0, { 10, 0 })

	choose_file_url("https://pgw.dev/finteqhub/billing/blob/feat/tax/internal/billing/invoice.go#L10")
end

T["git: Visual selection copies an ordered line range"] = function()
	open_repo_file(
		{ ["a.txt"] = "one\ntwo\nthree\nfour\nfive" },
		"https://github.com/owner/repo.git",
		"feature/share",
		"a.txt"
	)
	child.fn.setreg("+", "unchanged")
	open_file_url_picker("5GV3G<M-A>")
	child.type_keys("<CR>")
	local expected = "https://github.com/owner/repo/blob/feature/share/a.txt#L3-L5"
	assert(child.wait(([[vim.fn.getreg("+") == %q]]):format(expected), async_timeout()), "File URL was not copied")
	eq(child.fn.getreg("+"), expected)
end

T["git: A branch without an upstream is copied"] = function()
	open_repo_file({ ["a.txt"] = "one" }, "ssh://git@github.com/owner/repo.git", "topic/local-only", "a.txt")

	choose_file_url("https://github.com/owner/repo/blob/topic/local-only/a.txt#L1")
end

T["git: Unavailable file URL input preserves the clipboard"] = MiniTest.new_set()

T["git: Unavailable file URL input preserves the clipboard"]["without origin"] = function()
	local root = H.git_repo({ ["a.txt"] = "one" })
	child.wait_very_lazy()
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "a.txt")))

	choose_unavailable_file_url("Origin remote unavailable")
end

T["git: Unavailable file URL input preserves the clipboard"]["at detached HEAD"] = function()
	local root = H.git_repo({ ["a.txt"] = "one" }, { remote = "git@github.com:owner/repo.git" })
	H.git(root, { "checkout", "-q", "--detach" })
	child.wait_very_lazy()
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "a.txt")))

	choose_unavailable_file_url("Attached branch unavailable")
end

T["git: Unavailable file URL input preserves the clipboard"]["on an untracked file"] = function()
	local root = H.git_repo({ ["a.txt"] = "one" }, { remote = "git@github.com:owner/repo.git" })
	H.write_files(root, { ["new.txt"] = "new" })
	child.wait_very_lazy()
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "new.txt")))

	choose_unavailable_file_url("Tracked file unavailable")
end

T["git: Copy Commit URL is offered for a commit row"] = function()
	open_branch_commits()
	select_row("branch:commit:e325463")
	open_commit_url_picker()

	eq(child.lua_get([[require("gleb.actions").state.applicator.catalog:get("changes.copy_commit_url") == nil]]), true)
	eq(matched_action_ids(), {})
end

T["git: Copy Commit URL is absent away from commit rows"] = MiniTest.new_set()

T["git: Copy Commit URL is absent away from commit rows"]["file row"] = function()
	open_branch_commits()
	select_row("branch:commit:e325463:file:internal/billing/invoice.go")
	open_commit_url_picker()
	eq(matched_action_ids(), {})
end

T["git: Copy Commit URL is absent away from commit rows"]["Branch files view"] = function()
	open_branch_files()
	open_commit_url_picker()
	eq(matched_action_ids(), {})
end

return T
