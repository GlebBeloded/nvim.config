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
	a = "BufferLineBackground",
	b = "DevIconGo",
	c = "BufferLineFill",
	d = "ChangesTabInactive",
	e = "ChangesTabBranch",
	f = "WinSeparator",
	g = "DiffViewHeader",
	h = "ChangesBranchHeader",
	i = "ChangesCount",
	j = "DiffViewFold",
	k = "DiffViewLineNr",
	l = "DiffViewPadding",
	m = "@string",
	n = "FileTreeExpander",
	o = "FileTreeFolderIcon",
	p = "FileTreeFolderName",
	q = "FileTreeCursorLine",
	r = "ChangesCommittedFile",
	s = "ChangesStatAdded",
	t = "ChangesStatRemoved",
	u = "DiffViewCommitted",
	v = "@comment",
	w = "DiffViewArrowCommitted",
	x = "DiffViewGutterCommitted",
	y = "@keyword",
	z = "@type.definition",
	A = "@function.call",
	B = "@function",
	C = "DiffViewCommittedWord",
	D = "@property",
	E = "PickerBorder",
	F = "PickerHint",
	G = "lualine_a_normal",
	H = "lualine_b_normal",
	I = "lualine_x_diagnostics_error_command",
	J = "lualine_x_diagnostics_warn_command",
	K = "StatuslineLangCapError",
	L = "StatuslineLangText",
	M = "StatuslineLangEdge",
}

local BRANCH_FILES_MASK = {
	"....................................abbaaaaaaaaaaaaccccccccccccccccccccccccccccccccccccccccccccccccc",
	".ddddddddd.eeeeeeeeee..............fggggggggggggggggggggggggg.gggggggggggggggggggggggggggggggggggggg",
	".hhhhhhiiiiiiiiiiiiiiii............fjjkkkkkkkkkkkkkkkkkkkjjjjljjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj",
	".iiiiiiiiiiiiiiiiiiiiiiiiiiiiii....f.........................l.kkkk.....kkkk........................",
	"...................................f...mmmmmmmmmmmmmmmmmmmmmml.kkkk.....kkkk........................",
	".n.o.pppppppppppppppp.i............f.........................l.kkkk.....kkkk........................",
	"qqqnqbqrrrrrrrrrrqqqqqqqqqqqsssqttqf.........................l.kkkk.....kkkk........................",
	".......b.rrrrrrrrrrrrrrr....sss.tt.fuvvvvvvvvvvvvvvvvvvvvvvvvlwxxxxuuuuuxxxxxxuuuuuuuuuuuuuuuuuuuuuu",
	"...n.b.rrrrrr...............sss.tt.f.yyyy.zzzzzzz.yyyyyy.....l.kkkk.....kkkk........................",
	".......b.rrrrrrrrrrr........sss.tt.f...zz....AAAAAA..........l.kkkk.....kkkk........................",
	"...................................f...zzzzz...AAA...........l.kkkk.....kkkk........................",
	"...................................f...zzz...AAAA............l.kkkk.....kkkk........................",
	"...................................f.........................l.kkkk.....kkkk........................",
	"...................................f.........................l.kkkk.....kkkk........................",
	"...................................f.vvvvvvvvvvvvvvvvvvvvvvvvl.kkkk.....kkkk........................",
	"...................................f.yyyy....AAAAAAA..BBBBB..l.kkkk.....kkkk........................",
	"...................................fuuuuuuuuuCCCCuuuuuuuuuuuulwxxxxuuuuuxxxxxxuuCCCCuuuuuuCCCuuuuuuu",
	"...................................f...yyy.zm.zzzzz.yy.yyyyy.l.kkkk.....kkkk........................",
	"...................................f.....zzzzz.yy.zzzzz......l.kkkk.....kkkk........................",
	"...................................f.........................l.kkkk.....kkkk........................",
	"...................................fllllllllllllllllllllllllllwlllluuuuuxxxxxxuuuuuuuuuuuuuuuuuuuuuu",
	"...................................fllllllllllllllllllllllllll.lllluuuuuxxxxxxuuuuuuuuuuuuuuuuuuuuuu",
	"...................................fllllllllllllllllllllllllll.lllluuuuuxxxxxxuuuuuuuuuuuuuuuuuuuuuu",
	"...................................f...yyyyyy.zmDDDmBBBBB.zzzl.kkkk.....kkkk........................",
	"...................................f.........................l.kkkk.....kkkk........................",
	"...................................f.........................l.kkkk.....kkkk........................",
	"...................................f.vvvvvvvvvvvvvvvvvvvvvvvvl.kkkk.....kkkk........................",
	"EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEf.yyyy....AAAAAAA..BBB...Al.kkkk.....kkkk........................",
	"...........FFFFFFFFFFFFFFFFFFFFFFF.f...yyyyyy.zzzmBBBBBBB.mmml.kkkk.....kkkk........................",
	"GGGGGGGGHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHIIIIIJJJJKLLLLLLLLLLLLLLLLM",
}

local BRANCH_COMMITS_LEGEND = {
	a = "BufferLineBackground",
	b = "DevIconGo",
	c = "BufferLineFill",
	d = "ChangesTabInactive",
	e = "ChangesTabBranch",
	f = "WinSeparator",
	g = "DiffViewHeader",
	h = "ChangesBranchHeader",
	i = "ChangesCount",
	j = "DiffViewFold",
	k = "DiffViewLineNr",
	l = "DiffViewPadding",
	m = "FileTreeExpander",
	n = "ChangesCommitIcon",
	o = "ChangesRoot",
	p = "@string",
	q = "ChangesCommitHash",
	r = "FileTreeFileName",
	s = "FileTreeCursorLine",
	t = "ChangesCommittedFile",
	u = "ChangesStatAdded",
	v = "ChangesStatRemoved",
	w = "DiffViewCommitted",
	x = "@comment",
	y = "DiffViewArrowCommitted",
	z = "DiffViewGutterCommitted",
	A = "@keyword",
	B = "@type.definition",
	C = "@function.call",
	D = "@function",
	E = "DiffViewCommittedWord",
	F = "@property",
	G = "PickerBorder",
	H = "PickerHint",
	I = "lualine_a_normal",
	J = "lualine_b_normal",
	K = "lualine_x_diagnostics_error_command",
	L = "lualine_x_diagnostics_warn_command",
	M = "StatuslineLangCapError",
	N = "StatuslineLangText",
	O = "StatuslineLangEdge",
}

local BRANCH_COMMITS_MASK = {
	"....................................abbaaaaaaaaaaaaccccccccccccccccccccccccccccccccccccccccccccccccc",
	".ddddddddd.eeeeeeeeee..............fggggggggggggggggggggggggg.gggggggggggggggggggggggggggggggggggggg",
	".hhhhhhiiiiiiiiiiiiiiii............fjjkkkkkkkkkkkkkkkkkkkjjjjljjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj",
	"...................................f.........................l.kkkk.....kkkk........................",
	".m.n.ooooooooooo...........iiiiiii.f...ppppppppppppppppppppppl.kkkk.....kkkk........................",
	".m.n.qqqqqqq.rrrrrrrrrrrrrrrrri.ii.f.........................l.kkkk.....kkkk........................",
	"sssssbsttttttttttsssssssssssuuusvvsf.........................l.kkkk.....kkkk........................",
	".m.n.qqqqqqq.rrrrrrrrrrrrrrrrri.ii.fwxxxxxxxxxxxxxxxxxxxxxxxxlyzzzzwwwwwzzzzzzwwwwwwwwwwwwwwwwwwwwww",
	".m.n.qqqqqqq.rrrrrrrrrr.........ii.f.AAAA.BBBBBBB.AAAAAA.....l.kkkk.....kkkk........................",
	"...................................f...BB....CCCCCC..........l.kkkk.....kkkk........................",
	"...................................f...BBBBB...CCC...........l.kkkk.....kkkk........................",
	"...................................f...BBB...CCCC............l.kkkk.....kkkk........................",
	"...................................f.........................l.kkkk.....kkkk........................",
	"...................................f.........................l.kkkk.....kkkk........................",
	"...................................f.xxxxxxxxxxxxxxxxxxxxxxxxl.kkkk.....kkkk........................",
	"...................................f.AAAA....CCCCCCC..DDDDD..l.kkkk.....kkkk........................",
	"...................................fwwwwwwwwwEEEEwwwwwwwwwwwwlyzzzzwwwwwzzzzzzwwEEEEwwwwwwEEEwwwwwww",
	"...................................f...AAA.Bp.BBBBB.AA.AAAAA.l.kkkk.....kkkk........................",
	"...................................f.....BBBBB.AA.BBBBB......l.kkkk.....kkkk........................",
	"...................................f.........................l.kkkk.....kkkk........................",
	"...................................fllllllllllllllllllllllllllyllllwwwwwzzzzzzwwwwwwwwwwwwwwwwwwwwww",
	"...................................fllllllllllllllllllllllllll.llllwwwwwzzzzzzwwwwwwwwwwwwwwwwwwwwww",
	"...................................fllllllllllllllllllllllllll.llllwwwwwzzzzzzwwwwwwwwwwwwwwwwwwwwww",
	"...................................f...AAAAAA.BpFFFpDDDDD.BBBl.kkkk.....kkkk........................",
	"...................................f.........................l.kkkk.....kkkk........................",
	"...................................f.........................l.kkkk.....kkkk........................",
	"...................................f.xxxxxxxxxxxxxxxxxxxxxxxxl.kkkk.....kkkk........................",
	"GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGf.AAAA....CCCCCCC..DDD...Cl.kkkk.....kkkk........................",
	".............HHHHHHHHHHHHHHHHHHHHH.f...AAAAAA.BBBpDDDDDDD.pppl.kkkk.....kkkk........................",
	"IIIIIIIIJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJKKKKKLLLLMNNNNNNNNNNNNNNNNO",
}

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
				and view.diff_path == "branch:branch:commit:e325463:file:internal/billing/invoice.go"
				and view.diff_view.relpath == "internal/billing/invoice.go"
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

---@param name string
---@param columns integer
---@return string[]
local function approved_text(name, columns)
	local path = vim.fs.joinpath(H.root, "tests/screen/git", name .. ".ansi")
	return vim.tbl_map(function(line)
		local plain = line:gsub("\27%[[0-9;]*m", "")
		return table.concat(vim.list_slice(vim.fn.split(plain, [[\zs]]), 1, columns))
	end, vim.list_slice(vim.fn.readfile(path), 2, 29))
end

---@param columns integer
---@return string[]
local function screen_text(columns)
	return vim.tbl_map(function(cells)
		return table.concat(vim.list_slice(cells, 1, columns))
	end, vim.list_slice(child.get_screenshot().text, 2, 29))
end

local T = H.child_set(child, start)

T["git: Local tab matches the approved render"] = function()
	review_changes()
	wait_for_local_panel()
	H.expect_screen_colors(child, 2, LOCAL_MASK, PANEL_LEGEND, { columns = PANEL_COLUMNS })
	eq(screen_text(PANEL_COLUMNS), approved_text("local_tab", PANEL_COLUMNS))
end

T["git: Branch tab matches the approved render"] = function()
	review_changes()
	wait_for_local_panel()
	review_changes()
	wait_for_branch_panel(false)
	eq(screen_text(100), approved_text("branch_files", 100))
	H.expect_screen_colors(child, 2, vim.list_slice(BRANCH_FILES_MASK, 2, 29), BRANCH_FILES_LEGEND)
end

T["git: Branch commits match the approved render"] = function()
	review_changes()
	wait_for_local_panel()
	review_changes()
	wait_for_branch_panel(false)
	child.type_keys("c", "<Esc>")
	wait_for_branch_panel(true)
	eq(screen_text(100), approved_text("branch_commits", 100))
	H.expect_screen_colors(child, 2, vim.list_slice(BRANCH_COMMITS_MASK, 2, 29), BRANCH_COMMITS_LEGEND)
end

return T
