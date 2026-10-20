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
---@return string root
local function open_billing_branch(with_pr)
	local root, manifest = F.copy("billing-branch", vim.fn.tempname() .. "/billing-branch")
	root = vim.fs.normalize(vim.fn.resolve(root))
	local gh_dir = vim.fn.tempname()
	local files = pr482(manifest)
	if not with_pr then
		files["pr.json"] = nil
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

return T
