-- The approved Comments tab and peek screens of the pr-comments-view design, shared by the screen tests that
-- assert them (the peek screen's statusline is the statusline capability's approved render).

local F = require("tests.fixtures")
local H = require("tests.helpers")
local pr482 = require("tests.fixtures.gh.pr482")

local M = {}

--- The editor state of the approved captures, without the servers behind it: Tree-sitter's colours (gopls' semantic
--- tokens replace them once it has loaded the module), a running language server and golangci-lint's one warning on
--- line 4. Real gopls and golangci-lint runs would also serialise parallel children on the module and the lint lock.
---@param child test.Child
local function capture_environment(child)
	H.attach_fake_lsp(child)
	child.lua([[
		vim.diagnostic.set(vim.api.nvim_create_namespace("golangci_lint_capture"), 0, {
			{ lnum = 3, col = 0, severity = vim.diagnostic.severity.WARN, message = "typecheck: could not import fmt" },
		})
	]])
end

--- The approved screens are settled ones: ibl marks the scope after its debounce and lualine redraws on its refresh
--- timer. Wait until the editor's guides underline the start of `func (i Invoice) Total()` (line 17) and the
--- statusline shows the branch and `group` with no LSP progress left.
---@param child test.Child
---@param group string
---@param timeout integer
local function wait_for_redraws(child, group, timeout)
	assert(
		child.wait(
			([[(function()
			local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			local buf = vim.api.nvim_win_get_buf(panel.editor_win)
			local ns = vim.api.nvim_get_namespaces().indent_blankline
			local marks = vim.api.nvim_buf_get_extmarks(buf, ns, { 16, 0 }, { 16, -1 }, { details = true })
			local scope = vim.iter(marks):any(function(mark) return mark[4].hl_group == "@ibl.scope.underline.1" end)
			local statusline = vim.o.statusline
			return scope and statusline:find(%q, 1, true) ~= nil
				and statusline:find("feat/tax", 1, true) ~= nil and not statusline:find("\226[\160-\163]")
		end)()]]):format(group),
			timeout
		),
		"indent guides or statusline did not settle"
	)
end

---@param child test.Child
---@param id string
local function run_action(child, id)
	child.lua(
		[[
		local action = assert(require("gleb.actions").state.applicator.catalog:get(...))
		action.run(require("gleb.actions.context").capture())
	]],
		{ id }
	)
end

--- The approved Comments tab screen: `changes.review` three times on `invoice.go` of the `billing-branch` fixture
--- with `pr482` served, the panel cursor on the `:22` row, then the editor view restored to `topline = 6`.
---@param child test.Child
function M.show_comments(child)
	local root, manifest = F.copy("billing-branch", vim.fn.tempname() .. "/billing-branch")
	root = vim.fs.normalize(vim.fn.resolve(root))
	local gh_dir = vim.fn.tempname()
	H.write_files(gh_dir, pr482(manifest))
	child.start_config()
	child.wait_very_lazy()
	child.o.columns = 100
	child.o.lines = 30
	child.lua(
		[[
		vim.env.FAKE_GH_DIR = ...
		vim.lsp.enable("gopls", false)
		require("null-ls").disable({})
	]],
		{ gh_dir }
	)
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice.go")))
	capture_environment(child)
	child.lua(
		[[
		local root = ...
		Ready = false
		require("gleb.git.base").resolve(root, function()
			vim.api.nvim_create_autocmd("User", { pattern = "GlebPrThreads", once = true, callback = function() Ready = true end })
			require("gleb.pr").refresh(root)
		end)
	]],
		{ root }
	)
	assert(child.wait("Ready == true", math.floor(5000 * H.load_factor())))
	child.lua([[require("gleb.pr").now = function() return os.time({ year = 2026, month = 1, day = 2, hour = 1 }) end]])
	run_action(child, "changes.review")
	assert(child.wait(
		[[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return panel and panel.tabs_ready and panel.active_tab == "local" and panel.diff_view ~= nil
	end)()]],
		math.floor(5000 * H.load_factor())
	))
	run_action(child, "changes.review")
	assert(child.wait(
		[[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return panel and panel.active_tab == "branch"
	end)()]],
		math.floor(5000 * H.load_factor())
	))
	run_action(child, "changes.review")
	assert(child.wait(
		[[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return panel and panel.active_tab == "comments"
	end)()]],
		math.floor(5000 * H.load_factor())
	))
	child.lua([[
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		for index, line in ipairs(vim.api.nvim_buf_get_lines(panel.buf, 0, -1, false)) do
			if line:find(":22", 1, true) then vim.api.nvim_win_set_cursor(panel.win, { index, 0 }); break end
		end
	]])
	assert(child.wait(
		[[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local buf = vim.api.nvim_win_get_buf(panel.editor_win)
		local ns = vim.api.nvim_get_namespaces().gleb_pr_peek
		local marks = ns and vim.api.nvim_buf_get_extmarks(buf, ns, { 21, 0 }, { 21, -1 }, { details = true }) or {}
		return vim.api.nvim_win_get_cursor(panel.editor_win)[1] == 22
			and marks[1] and #marks[1][4].virt_lines == 8
	end)()]],
		math.floor(5000 * H.load_factor())
	))
	child.lua([[
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		vim.api.nvim_win_call(panel.editor_win, function() vim.fn.winrestview({ topline = 6 }) end)
	]])
	wait_for_redraws(child, "StatuslineLang_gleb_changes", math.floor(5000 * H.load_factor()))
end

--- The approved peek screen, from the Comments tab screen: the editor window current with its cursor on line 18, so
--- every peek is collapsed.
---@param child test.Child
function M.show_peeks(child)
	child.lua([[
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		vim.api.nvim_set_current_win(panel.editor_win)
		vim.fn.winrestview({ lnum = 18, topline = 6 })
	]])
	assert(
		child.wait(
			[[(function()
			local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			local buf = vim.api.nvim_win_get_buf(panel.editor_win)
			local ns = vim.api.nvim_get_namespaces().gleb_pr_peek
			local marks = vim.api.nvim_buf_get_extmarks(buf, ns, { 21, 0 }, { 21, -1 }, { details = true })
			return marks[1] and #marks[1][4].virt_lines == 1
		end)()]],
			math.floor(5000 * H.load_factor())
		),
		"the :22 peek did not collapse"
	)
	wait_for_redraws(child, "StatuslineLangCapOk", math.floor(5000 * H.load_factor()))
end

return M
