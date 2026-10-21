-- Approved tabbed Changes panel renders from the git-changes-tabs design.
local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")
local pr482 = require("tests.fixtures.gh.pr482")

local eq = MiniTest.expect.equality
local child = H.new_child()

local PANEL_COLUMNS = 36
local fixture_manifest

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
	".ddddddddd.eeeeeeeeee.eeeeeeeeeeee.f",
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
	a = "ChangesTabInactive",
	b = "ChangesTabBranch",
	c = "WinSeparator",
	d = "DiffViewHeader",
	e = "ChangesBranchHeader",
	f = "ChangesCount",
	g = "DiffViewFold",
	h = "DiffViewLineNr",
	i = "DiffViewPadding",
	j = "@string",
	k = "FileTreeExpander",
	l = "FileTreeFolderIcon",
	m = "FileTreeFolderName",
	n = "FileTreeCursorLine",
	o = "DevIconGo",
	p = "ChangesCommittedFile",
	q = "ChangesStatAdded",
	r = "ChangesStatRemoved",
	s = "DiffViewChange",
	t = "@comment",
	u = "DiffViewArrowChange",
	v = "DiffViewGutterChange",
	w = "@keyword",
	x = "@type.definition",
	y = "DiffViewWord",
	z = "@function.call",
	A = "@function",
	B = "DiffViewArrowAdd",
	C = "DiffViewAdd",
	D = "DiffViewGutterAdd",
	E = "@property",
	F = "PickerBorder",
	G = "PickerHint",
}

local BRANCH_FILES_MASK = {
	".aaaaaaaaa.bbbbbbbbbb.aaaaaaaaaaaa.cdddddddddddddddddddddddddidddddddddddddddddddddddddddddddddddddd",
	".eeeeeeffffffffffffffff............cgghhhhhhhhhhhhhhhhhhhggggigggggggggggggggggggggggggggggggggggggg",
	".ffffffffffffffffffffffffffffff....c.........................i.hhhh.....hhhh..g.....................",
	"...................................c...jjjjjjjjjjjjjjjjjjjjjji.hhhh.....hhhh..ggjjjjjjjjjjjjjjjjjjjj",
	".k.l.mmmmmmmmmmmmmmmm.f............c.........................i.hhhh.....hhhh........................",
	"nnnknonppppppppppnnnnnnnnnnnqqqnrrnc.........................i.hhhh.....hhhh........................",
	".......o.ppppppppppppppp....qqq.rr.csttttttttttttttttttttttttiuvvvvsssssvvvvvvtttttttttttttttttttttt",
	"...k.o.pppppp...............qqq.rr.c.wwww.xxxxxxx.wwwwww.....i.hhhh.....hhhh..wwww.xxxxxxx.wwwwww...",
	".......o.ppppppppppp........qqq.rr.csssssssssssssssssssssssssiuvvvvsssssvvvvvvssssssssssssssyttttttt",
	"...................................c...xxxxx...zzz...........i.hhhh.....hhhh..ggxxxxx...zzz.........",
	"...................................c...xxx...zzzz............i.hhhh.....hhhh..ggxxx...zzzz..........",
	"...................................c.........................i.hhhh.....hhhh........................",
	"...................................c.........................i.hhhh.....hhhh........................",
	"...................................c.tttttttttttttttttttttttti.hhhh.....hhhh..tttttttttttttttttttttt",
	"...................................c.wwww....zzzzzzz..AAAAA..i.hhhh.....hhhh..wwww....zzzzzzz..AAAAA",
	"...................................csssssssssyyyyssssssssssssiuvvvvsssssvvvvvvssyyyyssssssyyysssssss",
	"...................................c...www.xj.xxxxx.ww.wwwww.i.hhhh.....hhhh..ggwww.xj.xxxxx.ww.wwww",
	"...................................c.....xxxxx.ww.xxxxx......i.hhhh.....hhhh..ggggxxxxx.ww.xxxxx....",
	"...................................c.........................i.hhhh.....hhhh..gg....................",
	"...................................ciiiiiiiiiiiiiiiiiiiiiiiiiiBiiiiCCCCCDDDDDDCCCCCCCCCCCCCCCCCCCCCC",
	"...................................ciiiiiiiiiiiiiiiiiiiiiiiiii.iiiiCCCCCDDDDDDCCCCCCCCCCCCCCCCCCCCCC",
	"...................................ciiiiiiiiiiiiiiiiiiiiiiiiii.iiiiCCCCCDDDDDDCCCCCCCCCCCCCCCCCCCCCC",
	"...................................c...wwwwww.xjEEEjAAAAA.xxxi.hhhh.....hhhh..ggwwwwww.xjEEEjAAAAA.x",
	"...................................c.........................i.hhhh.....hhhh........................",
	"...................................c.........................i.hhhh.....hhhh........................",
	"...................................c.tttttttttttttttttttttttti.hhhh.....hhhh..tttttttttttttttttttttt",
	"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFc.wwww....zzzzzzz..AAA...zi.hhhh.....hhhh..wwww....zzzzzzz..AAA..",
	"...........GGGGGGGGGGGGGGGGGGGGGGG.c...wwwwww.xxxjAAAAAAA.jjji.hhhh.....hhhh..ggwwwwww.xxxjAAAAAAA.j",
}

local BRANCH_COMMITS_LEGEND = {
	a = "ChangesTabInactive",
	b = "ChangesTabBranch",
	c = "WinSeparator",
	d = "DiffViewHeader",
	e = "ChangesBranchHeader",
	f = "ChangesCount",
	g = "DiffViewFold",
	h = "DiffViewLineNr",
	i = "DiffViewPadding",
	j = "FileTreeExpander",
	k = "ChangesCommitIcon",
	l = "ChangesRoot",
	m = "@string",
	n = "ChangesCommitHash",
	o = "FileTreeFileName",
	p = "FileTreeCursorLine",
	q = "DevIconGo",
	r = "ChangesCommittedFile",
	s = "ChangesStatAdded",
	t = "ChangesStatRemoved",
	u = "DiffViewChange",
	v = "@comment",
	w = "DiffViewArrowChange",
	x = "DiffViewGutterChange",
	y = "@keyword",
	z = "@type.definition",
	A = "@function.call",
	B = "@function",
	C = "DiffViewWord",
	D = "DiffViewArrowAdd",
	E = "DiffViewAdd",
	F = "DiffViewGutterAdd",
	G = "@property",
	H = "PickerBorder",
	I = "PickerHint",
}

local BRANCH_COMMITS_MASK = {
	".aaaaaaaaa.bbbbbbbbbb.aaaaaaaaaaaa.cdddddddddddddddddddddddddidddddddddddddddddddddddddddddddddddddd",
	".eeeeeeffffffffffffffff............cgghhhhhhhhhhhhhhhhhhhggggigggggggggggggggggggggggggggggggggggggg",
	"...................................c.........................i.hhhh.....hhhh........................",
	".j.k.lllllllllll...........fffffff.c...mmmmmmmmmmmmmmmmmmmmmmi.hhhh.....hhhh....mmmmmmmmmmmmmmmmmmmm",
	".j.k.nnnnnnn.ooooooooooooooooof.ff.c.........................i.hhhh.....hhhh........................",
	"pppppqprrrrrrrrrrpppppppppppssspttpc.........................i.hhhh.....hhhh........................",
	".j.k.nnnnnnn.ooooooooooooooooof.ff.cuvvvvvvvvvvvvvvvvvvvvvvvviwxxxxuuuuuxxxxxxvvvvvvvvvvvvvvvvvvvvvv",
	".j.k.nnnnnnn.oooooooooo.........ff.c.yyyy.zzzzzzz.yyyyyy.....i.hhhh.....hhhh..yyyy.zzzzzzz.yyyyyy...",
	"...................................c...zz....AAAAAA..........i.hhhh.....hhhh....zz....AAAAAA........",
	"...................................c...zzzzz...AAA...........i.hhhh.....hhhh....zzzzz...AAA.........",
	"...................................c...zzz...AAAA............i.hhhh.....hhhh....zzz...AAAA..........",
	"...................................c.........................i.hhhh.....hhhh........................",
	"...................................c.........................i.hhhh.....hhhh........................",
	"...................................c.vvvvvvvvvvvvvvvvvvvvvvvvi.hhhh.....hhhh..vvvvvvvvvvvvvvvvvvvvvv",
	"...................................c.yyyy....AAAAAAA..BBBBB..i.hhhh.....hhhh..yyyy....AAAAAAA..BBBBB",
	"...................................cuuuuuuuuuCCCCuuuuuuuuuuuuiwxxxxuuuuuxxxxxxuuCCCCuuuuuuCCCuuuuuuu",
	"...................................c...yyy.zm.zzzzz.yy.yyyyy.i.hhhh.....hhhh....yyy.zm.zzzzz.yy.yyyy",
	"...................................c.....zzzzz.yy.zzzzz......i.hhhh.....hhhh......zzzzz.yy.zzzzz....",
	"...................................c.........................i.hhhh.....hhhh........................",
	"...................................ciiiiiiiiiiiiiiiiiiiiiiiiiiDiiiiEEEEEFFFFFFEEEEEEEEEEEEEEEEEEEEEE",
	"...................................ciiiiiiiiiiiiiiiiiiiiiiiiii.iiiiEEEEEFFFFFFEEEEEEEEEEEEEEEEEEEEEE",
	"...................................ciiiiiiiiiiiiiiiiiiiiiiiiii.iiiiEEEEEFFFFFFEEEEEEEEEEEEEEEEEEEEEE",
	"...................................c...yyyyyy.zmGGGmBBBBB.zzzi.hhhh.....hhhh....yyyyyy.zmGGGmBBBBB.z",
	"...................................c.........................i.hhhh.....hhhh........................",
	"...................................c.........................i.hhhh.....hhhh........................",
	"...................................c.vvvvvvvvvvvvvvvvvvvvvvvvi.hhhh.....hhhh..vvvvvvvvvvvvvvvvvvvvvv",
	"HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHc.yyyy....AAAAAAA..BBB...Ai.hhhh.....hhhh..yyyy....AAAAAAA..BBB..",
	".............IIIIIIIIIIIIIIIIIIIII.c...yyyyyy.zzzmBBBBBBB.mmmi.hhhh.....hhhh....yyyyyy.zzzmBBBBBBB.m",
}

---@param root string
local function report_pull_request(root)
	local output = vim.fn.tempname()
	local base = vim.trim(H.git(root, { "rev-parse", "origin/main" }))
	local head = vim.trim(H.git(root, { "rev-parse", "HEAD" }))
	vim.fn.writefile({
		vim.json.encode({
			number = 482,
			url = "https://example.test/owner/repo/pull/482",
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
	local root
	root, fixture_manifest = F.copy("billing-branch", vim.fs.joinpath(home, "work", "billing-branch"))
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
				and view.diff_path == "branch:branch:file:internal/billing/invoice.go"
				and view.diff_view.labels.left == "4ccefde · main"
				and view.diff_view.labels.right == "Your version"]]
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

---@param name string
---@param columns integer
---@return string[]
local function approved_text_with_comments(name, columns)
	local expected = approved_text(name, columns)
	expected[1] = "  Local 3   Branch 4   Comments 0  ┃" .. vim.fn.strcharpart(expected[1], PANEL_COLUMNS)
	return expected
end

local T = H.child_set(child, start)

T["git: Local tab matches the approved render"] = function()
	review_changes()
	wait_for_local_panel()
	H.expect_screen_colors(child, 2, LOCAL_MASK, PANEL_LEGEND, { columns = PANEL_COLUMNS })
	eq(screen_text(PANEL_COLUMNS), approved_text_with_comments("local_tab", PANEL_COLUMNS))

	local gh_dir = vim.fn.tempname()
	H.write_files(gh_dir, pr482(fixture_manifest))
	child.lua(
		[[vim.env.FAKE_GH_STDOUT = nil; vim.env.FAKE_GH_DIR = ...
		local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		require("gleb.pr").refresh(view.root)]],
		{ gh_dir }
	)
	assert(
		child.wait(
			[[(function()
				local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				return view and vim.api.nvim_eval_statusline(vim.wo[view.win].winbar, { winid = view.win }).str
					:find("Comments 3", 1, true) ~= nil
			end)()]],
			5000
		),
		"Comments tab count did not follow review threads"
	)
end

T["git: Branch tab matches the approved render"] = function()
	review_changes()
	wait_for_local_panel()
	review_changes()
	wait_for_branch_panel(false)
	eq(screen_text(100), approved_text_with_comments("branch_files", 100))
	H.expect_screen_colors(child, 2, BRANCH_FILES_MASK, BRANCH_FILES_LEGEND)
end

T["git: Branch commits match the approved render"] = function()
	review_changes()
	wait_for_local_panel()
	review_changes()
	wait_for_branch_panel(false)
	child.type_keys("c", "<Esc>")
	wait_for_branch_panel(true)
	eq(screen_text(100), approved_text_with_comments("branch_commits", 100))
	H.expect_screen_colors(child, 2, BRANCH_COMMITS_MASK, BRANCH_COMMITS_LEGEND)
end

return T
