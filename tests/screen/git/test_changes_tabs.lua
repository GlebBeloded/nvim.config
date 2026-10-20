-- Approved tabbed Changes panel renders from the git-changes-tabs design.
local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local PANEL_COLUMNS = 36

local PANEL_LEGEND = {
	d = "ChangesTabLocal",
	e = "ChangesTabInactive",
	f = "WinSeparator",
	h = "ChangesCount",
	i = "ChangesRoot",
	m = "FileTreeFolderIcon",
	n = "FileTreeCursorLine",
	p = "ChangesStatAdded",
	q = "ChangesStatRemoved",
	x = "DevIconMd",
	y = "FileTreeGitUntracked",
	z = "DevIconTypeScript",
}

local function panel_mask(prefixes)
	return vim.tbl_map(function(prefix)
		return prefix .. string.rep(".", 100 - #prefix)
	end, prefixes)
end

local LOCAL_MASK = panel_mask({
	".ddddddddd.eeeeeeeeee..............f",
	".h.h.iiiiiii.hhhhhhh...............f",
	"...h.m..................h..........f",
	"nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnf",
	"...h.m.........h...................f",
	".......h.z.mmmmmmmm..........pp.qq.f",
	".h.h.iiiiiiiiiiiiiiiii.hhhhhh......f",
	".....h.x.yyyyyyyy..................f",
	"...................................f",
	"...................................f",
	"...................................f",
	"...................................f",
	"...................................f",
	"...................................f",
	"...................................f",
	"...................................f",
	"...................................f",
	"...................................f",
	"...................................f",
	"...................................f",
	"...................................f",
	"...................................f",
	"...................................f",
	"...................................f",
	"...................................f",
	"...................................f",
	"...................................f",
	"...................................f",
})

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

local function start()
	local home = vim.fn.tempname()
	local root = F.copy("billing-branch", vim.fs.joinpath(home, "work", "billing-branch"))
	child.start_config()
	child.o.lines, child.o.columns = 30, 100
	child.wait_very_lazy()
	child.lua(
		[[
		vim.env.HOME = ...
		vim.lsp.enable("gopls", false)
		require("null-ls").disable({})
		vim.diagnostic.enable(false)
	]],
		{ home }
	)
	report_pull_request(root)
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice.go")))
end

local function review_changes()
	child.lua([[
		local action = assert(require("gleb.actions").state.applicator.catalog:get("changes.review"))
		action.run(require("gleb.actions.context").capture())
	]])
end

local function wait_for_local_panel()
	assert(
		child.wait(
			[[(function()
			local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return view
				and view.active_tab == "local"
				and view.branch_count == 4
				and view.diff_view ~= nil
				and vim.api.nvim_get_current_win() == view.win
		end)()]],
			5000
		),
		"Local changes review did not finish loading"
	)
	child.cmd("redraw")
end

---@return string[]
local function approved_panel_text()
	local path = vim.fs.joinpath(H.root, "tests/screen/git/local_tab.ansi")
	return vim.tbl_map(function(line)
		local plain = line:gsub("\27%[[0-9;]*m", "")
		return table.concat(vim.list_slice(vim.fn.split(plain, [[\zs]]), 1, PANEL_COLUMNS))
	end, vim.list_slice(vim.fn.readfile(path), 2, 29))
end

---@return string[]
local function panel_text()
	return vim.tbl_map(function(cells)
		return table.concat(vim.list_slice(cells, 1, PANEL_COLUMNS))
	end, vim.list_slice(child.get_screenshot().text, 2, 29))
end

local T = H.child_set(child, start)

T["git: Local tab matches the approved render"] = function()
	review_changes()
	wait_for_local_panel()
	H.expect_screen_colors(child, 2, LOCAL_MASK, PANEL_LEGEND, { columns = PANEL_COLUMNS })
	eq(panel_text(), approved_panel_text())
end

return T
