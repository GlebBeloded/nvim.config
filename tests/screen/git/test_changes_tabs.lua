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

local BRANCH_FILES_LEGEND = {
	b = "DevIconGo",
	d = "ChangesTabInactive",
	e = "ChangesTabBranch",
	f = "WinSeparator",
	h = "ChangesBranchHeader",
	i = "ChangesCount",
	n = "FileTreeExpander",
	o = "FileTreeFolderIcon",
	p = "FileTreeFolderName",
	q = "FileTreeCursorLine",
	r = "ChangesCommittedFile",
	s = "ChangesStatAdded",
	t = "ChangesStatRemoved",
	E = "PickerBorder",
	F = "PickerHint",
}

local BRANCH_FILES_MASK = panel_mask(vim.list_extend(
	{
		".ddddddddd.eeeeeeeeee..............f",
		".hhhhhhiiiiiiiiiiiiiiii............f",
		".iiiiiiiiiiiiiiiiiiiiiiiiiiiiii....f",
		"...................................f",
		".n.o.pppppppppppppppp.i............f",
		"qqqnqbqrrrrrrrrrrqqqqqqqqqqqsssqttqf",
		".......b.rrrrrrrrrrrrrrr....sss.tt.f",
		"...n.b.rrrrrr...............sss.tt.f",
		".......b.rrrrrrrrrrr........sss.tt.f",
	},
	vim.list_extend(vim.fn["repeat"]({ "...................................f" }, 17), {
		"EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEf",
		"...........FFFFFFFFFFFFFFFFFFFFFFF.f",
	})
))

local BRANCH_COMMITS_LEGEND = {
	b = "DevIconGo",
	d = "ChangesTabInactive",
	e = "ChangesTabBranch",
	f = "WinSeparator",
	h = "ChangesBranchHeader",
	i = "ChangesCount",
	m = "FileTreeExpander",
	n = "ChangesCommitIcon",
	o = "ChangesRoot",
	q = "ChangesCommitHash",
	r = "FileTreeFileName",
	s = "FileTreeCursorLine",
	t = "ChangesCommittedFile",
	u = "ChangesStatAdded",
	v = "ChangesStatRemoved",
	G = "PickerBorder",
	H = "PickerHint",
}

local BRANCH_COMMITS_MASK = panel_mask(vim.list_extend(
	{
		".ddddddddd.eeeeeeeeee..............f",
		".hhhhhhiiiiiiiiiiiiiiii............f",
		"...................................f",
		".m.n.ooooooooooo...........iiiiiii.f",
		".m.n.qqqqqqq.rrrrrrrrrrrrrrrrri.ii.f",
		"sssssbsttttttttttsssssssssssuuusvvsf",
		".m.n.qqqqqqq.rrrrrrrrrrrrrrrrri.ii.f",
		".m.n.qqqqqqq.rrrrrrrrrr.........ii.f",
	},
	vim.list_extend(vim.fn["repeat"]({ "...................................f" }, 18), {
		"GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGf",
		".............HHHHHHHHHHHHHHHHHHHHH.f",
	})
))

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
		require("gleb.git.changes.branch").now = function() return 1767315600 end
	]],
		{ home }
	)
	report_pull_request(root)
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice.go")))
end

---@param commit_view boolean
local function wait_for_branch_panel(commit_view)
	local ready = commit_view
			and [[view.rows[5] and view.rows[5].id == "branch:commit:e325463:file:internal/billing/invoice.go"
				and view.diff_view.labels.right == "e325463 · wire tax into Total"]]
		or [[view.rows[8] and view.rows[8].id == "branch:file:internal/billing/tax_test.go"
				and view.diff_view.labels.right == "e325463 · HEAD"]]
	assert(
		child.wait(
			([[(function()
			local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return view
				and view.active_tab == "branch"
				and view.commit_view == %s
				and view.diff_view ~= nil
				and %s
		end)()]]):format(tostring(commit_view), ready),
			5000
		),
		"Branch changes review did not finish loading"
	)
	child.cmd("redraw")
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

---@param head string[]
---@param blank_count integer
---@param hint string
---@return string[]
local function branch_panel_text(head, blank_count, hint)
	local blank = (" "):rep(35) .. "┃"
	local expected = vim.deepcopy(head)
	vim.list_extend(expected, vim.fn["repeat"]({ blank }, blank_count))
	expected[#expected + 1] = ("─"):rep(35) .. "┃"
	expected[#expected + 1] = hint .. "┃"
	return expected
end

local T = H.child_set(child, start)

T["git: Local tab matches the approved render"] = function()
	review_changes()
	wait_for_local_panel()
	H.expect_screen_colors(child, 2, LOCAL_MASK, PANEL_LEGEND, { columns = PANEL_COLUMNS })
	eq(panel_text(), approved_panel_text())
end

T["git: Branch tab matches the approved render"] = function()
	review_changes()
	wait_for_local_panel()
	review_changes()
	wait_for_branch_panel(false)
	eq(
		panel_text(),
		branch_panel_text({
			"  Local 3   Branch 4               ┃",
			"  #482 feat/tax → main            ┃",
			" 3 commits · merge-base 4ccefde    ┃",
			(" "):rep(35) .. "┃",
			"   internal/billing 4            ┃",
			"     invoice.go           +11 -2 ┃",
			"        invoice_test.go    +20 -1 ┃",
			"     tax.go               +41 -0 ┃",
			"        tax_test.go        +33 -0 ┃",
		}, 17, "           Commits c · Next tab ⌘G ")
	)
	H.expect_screen_colors(child, 2, BRANCH_FILES_MASK, BRANCH_FILES_LEGEND, { columns = PANEL_COLUMNS })
end

T["git: Branch commits match the approved render"] = function()
	review_changes()
	wait_for_local_panel()
	review_changes()
	wait_for_branch_panel(false)
	child.type_keys("c", "<Esc>")
	wait_for_branch_panel(true)
	eq(
		panel_text(),
		branch_panel_text({
			"  Local 3   Branch 4               ┃",
			"  #482 feat/tax → main            ┃",
			(" "):rep(35) .. "┃",
			"  ◆ All changes           4 files ┃",
			"  ◆ e325463 wire tax into Tot… 1h ┃",
			"      invoice.go           +11 -2 ┃",
			"  ◆ 07cb52e add Rate and tax … 3h ┃",
			"  ◆ b5435c5 add tax.go         1d ┃",
		}, 18, "             Files c · Next tab ⌘G ")
	)
	H.expect_screen_colors(child, 2, BRANCH_COMMITS_MASK, BRANCH_COMMITS_LEGEND, { columns = PANEL_COLUMNS })
end

return T
