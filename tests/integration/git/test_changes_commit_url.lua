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

---@return string[]
local function matched_action_ids()
	return child.lua_get([[
		vim.iter(require("mini.pick").get_picker_matches().all)
			:filter(function(row) return row.action ~= nil end)
			:map(function(row) return row.action.id end)
			:totable()
	]])
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
