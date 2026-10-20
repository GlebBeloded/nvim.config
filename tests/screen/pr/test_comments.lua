local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")
local pr482 = require("tests.fixtures.gh.pr482")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function run_action(id)
	child.lua(
		[[
		local action = assert(require("gleb.actions").state.applicator.catalog:get(...))
		action.run(require("gleb.actions.context").capture())
	]],
		{ id }
	)
end

local function start()
	local root, manifest = F.copy("billing-branch", vim.fn.tempname() .. "/billing-branch")
	root = vim.fs.normalize(vim.fn.resolve(root))
	local gh_dir = vim.fn.tempname()
	H.write_files(gh_dir, pr482(manifest))
	child.start_config()
	child.wait_very_lazy()
	child.o.columns = 100
	child.o.lines = 30
	child.lua([[vim.env.FAKE_GH_DIR = ...]], { gh_dir })
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice.go")))
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
	run_action("changes.review")
	assert(child.wait(
		[[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return panel and panel.tabs_ready and panel.active_tab == "local"
	end)()]],
		math.floor(5000 * H.load_factor())
	))
	run_action("changes.review")
	assert(child.wait(
		[[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return panel and panel.active_tab == "branch"
	end)()]],
		math.floor(5000 * H.load_factor())
	))
	run_action("changes.review")
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
end

local T = H.child_set(child, start)

local COMMENTS_LEGEND = {
	a = "BufferLineBufferSelected",
	b = "DevIconGo",
	c = "BufferLineFill",
	d = "ChangesTabInactive",
	e = "ChangesTabComments",
	f = "WinSeparator",
	g = "LineNr",
	h = "@keyword",
	i = "@type.definition",
	j = "ChangesBranchHeader",
	k = "ChangesCount",
	l = "GitSignsChange",
	m = "GitSignsAdd",
	n = "@comment",
	o = "PrThreadResolved",
	p = "FileTreeExpander",
	q = "FileTreeFolderIcon",
	r = "FileTreeFolderName",
	s = "ChangesCommittedFile",
	t = "PrPeekMeta",
	u = "PrPeekIcon",
	v = "PrPeekAuthor",
	w = "PrPeek",
	x = "FileTreeCursorLine",
	y = "PrThreadOutdated",
	z = "GitCommittedSign",
	A = "@property",
	B = "lualine_a_normal",
	C = "lualine_b_normal",
	D = "PrStatuslineNumber",
	E = "PrStatuslineThreads",
	F = "lualine_x_diagnostics_error_command",
	G = "lualine_x_diagnostics_warn_command",
	H = "StatuslineLangCapError",
	I = "StatuslineLangText",
	J = "StatuslineLang_gleb_changes",
	K = "StatuslineLangEdge",
}

local COMMENTS_MASK = {
	"....................................abaaaaaaaaaaaaaccccccccccccccccccccccccccccccccccccccccccccccccc",
	".ddddddddd.dddddddddd.eeeeeeeeeeee.f..gggghhhh.iiiiiii.hhhhhh.......................................",
	".jjjjjjkkkkkkkkkkkkkkkk............fllggggggii....mmmmmm.nnnnnnnnnnnnnnnnn..........................",
	".kkkkkkkkkkkkkkkkkkk...............f..gggg..ooooooooooooooooooooooooooooooooooooooooooooooooooooo...",
	"...................................f..ggggggiiiii...mmm.............................................",
	".p.q.rrrrrrrrrrrrrrrr.k............f..ggggggiii...mmmm..............................................",
	"...p.b.ssssssssss.k................f..gggg..tttuuvvvvvv.wwww.ww.wwwww.wwwww.........................",
	".....u.ttt.vvvvvv.wwwwwwwwwwwwww...f..gggg..........................................................",
	"xxxxxuxtttxvvvvvvvxwwwwwwwwwwwwwxxxf..gggg..........................................................",
	".....oooooooooooooooooooooooooooo..f..ggggnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn.........",
	"...p.b.ssssss.k....................f..gggg..........................................................",
	".....u.ttt.vvvvvvv.wwwwww.yyyyyyyy.fzzggggtghhh.iiiii.mmm...........................................",
	"...................................f..ggggtghhh.iu.iiiii.hh.hhhhh.iuAAAAA...........................",
	"...................................f..ggggtgggiiiii.hh.iiiii........................................",
	"...................................f..ggggtg........................................................",
	"...................................fzzggggtghh.iuAAA.hh.AAA.........................................",
	"...................................f..gggg..ttuuuuuuuuuuuuuuuuuuuuuuuutttttttttttttttttttttttttttttt",
	"...................................f..gggg..ttvvvvvvvttttt........................................tt",
	"...................................f..gggg..ttwwwwww.w.www.wwww.wwww.ww.www.ww.wwww...............tt",
	"...................................f..gggg..ttw.wwwwwww.wwwwww.wwwww.wwwwwwww.wwww.wwww...........tt",
	"...................................f..gggg..ttvvvvvvvvvvvvttttt...................................tt",
	"...................................f..gggg..ttwwww.wwwwww.wwwwwwwwww.ww.wwwwwww.www...............tt",
	"...................................f..gggg..ttwwwwwww.w.wwwwwwww..................................tt",
	"...................................f..gggg..tttttttttttttttttttttttttttttttttttttttttttttttttttttttt",
	"...................................fzzggggtggghhhhhh.iiiii..........................................",
	"...................................fzzggggtg........................................................",
	"...................................f..ggggtghhhhhh.iuAAAulllll.iiiii................................",
	"...................................f..gggg..........................................................",
	"...................................f..gggg..........................................................",
	"BBBBBBBBCCCCCCCCCCCCCDDDDDDCCEEECCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCFFFFGGGGHIJIIIIIIIIIIIIIIK",
}

local function padded(lines)
	return vim.tbl_map(function(line)
		return line .. string.rep(" ", 100 - vim.fn.strdisplaywidth(line))
	end, lines)
end

local COMMENTS_TEXT = padded({
	"                                     ◆ invoice.go",
	"  Local 3   Branch 4   Comments 3  ┃   12 type Invoice struct {",
	" ◆ #482 feat/tax → main            ┃┃  11 ▏ ID    string // invoice number",
	" 3 open · 1 resolved               ┃        ╰─ ◆ Resolved · ivan.p: Should ID stay a string? The…",
	"                                   ┃   10 ▏ Lines []int",
	" ▾ ◆ internal/billing 3            ┃    9 ▏ Tax   Rate",
	"   ▾ ◆ invoice.go 2                ┃        ╰─ ◆ ivan.p Rate or *Rate here?",
	"     ◆ :13 ivan.p Rate or *Rate…   ┃    8 }",
	"     ◆ :22 maria.k Should a nil…   ┃    7",
	"     ◆ :11 ivan.p Should ID stay…  ┃    6 // Total sums the lines and applies the tax rate.",
	"   ▾ ◆ tax.go 1                    ┃    5 func (i Invoice) Total() int {",
	"     ◆ :18 maria.k Round… outdated ┃┃   4 ▏ var total int",
	"                                   ┃    3 ▏ for _, cents := range i.Lines {",
	"                                   ┃    2 ▏ ▏ total += cents",
	"                                   ┃    1 ▏ }",
	"                                   ┃┃ 22  ▏ if i.Tax == nil {",
	"                                   ┃        ╭─ ◆ PR #482 · 2 comments ─────────────────────────────╮",
	"                                   ┃        │ maria.k · 2h                                         │",
	"                                   ┃        │ Should a nil rate mean no tax at all?                │",
	"                                   ┃        │ A missing config would silently drop tax.            │",
	"                                   ┃        │ gleb-beloded · 1h                                    │",
	"                                   ┃        │ Good catch, defaulting to Rate(0) and                │",
	"                                   ┃        │ logging a warning.                                   │",
	"                                   ┃        ╰──────────────────────────────────────────────────────╯",
	"                                   ┃┃   1 ▏ ▏ return total",
	"                                   ┃┃   2 ▏ }",
	"                                   ┃    3 ▏ return i.Tax.Apply(total)",
	"                                   ┃    4 }",
	"                                   ┃    5",
	" NORMAL  ⎇ feat/tax  ◆ #482  ◆ 3                                          ◆ 0 ◆ 0 ◆ ◆ gleb-changes ◆",
})

local PEEK_LEGEND = {
	a = "BufferLineIndicatorSelected",
	b = "DevIconGo",
	c = "BufferLineBufferSelected",
	d = "BufferLineCloseButtonSelected",
	e = "BufferLineFill",
	f = "ChangesTabInactive",
	g = "ChangesTabComments",
	h = "WinSeparator",
	i = "LineNr",
	j = "ChangesBranchHeader",
	k = "ChangesCount",
	l = "GitCommittedSign",
	m = "@comment",
	n = "@keyword",
	o = "@type.definition",
	p = "FileTreeExpander",
	q = "FileTreeFolderIcon",
	r = "FileTreeFolderName",
	s = "GitSignsChange",
	t = "GitSignsAdd",
	u = "ChangesCommittedFile",
	v = "PrThreadResolved",
	w = "PrPeekIcon",
	x = "PrPeekMeta",
	y = "PrPeekAuthor",
	z = "PrPeek",
	A = "FileTreeCursorLine",
	B = "PrThreadOutdated",
	C = "@property",
	D = "lualine_a_normal",
	E = "lualine_b_normal",
	F = "PrStatuslineNumber",
	G = "PrStatuslineThreads",
	H = "lualine_x_diagnostics_error_command",
	I = "lualine_x_diagnostics_warn_command",
	J = "StatuslineLangCapOk",
	K = "StatuslineLangText",
	L = "StatuslineLang_go",
	M = "StatuslineLangEdge",
}

local PEEK_MASK = {
	"....................................abbcccccccccccdeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
	".fffffffff.ffffffffff.gggggggggggg.h..iiii..........................................................",
	".jjjjjjkkkkkkkkkkkkkkkk............h..iiii..........................................................",
	".kkkkkkkkkkkkkkkkkkk...............hlliiiimmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm",
	"...................................h..iiiinnnn.ooooooo.nnnnnn.......................................",
	".p.q.rrrrrrrrrrrrrrrr.k............hssiiiiiioo....tttttt.mmmmmmmmmmmmmmmmm..........................",
	"...p.b.uuuuuuuuuu.k................h..iiii..vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv...",
	".....w.xxx.yyyyyy.zzzzzzzzzzzzzz...h..iiiiiiooooo...ttt.............................................",
	"AAAAAwAxxxAyyyyyyyAzzzzzzzzzzzzzAAAh..iiiiiiooo...tttt..............................................",
	".....vvvvvvvvvvvvvvvvvvvvvvvvvvvv..h..iiii..xxxwwyyyyyy.zzzz.zz.zzzzz.zzzzz.........................",
	"...p.b.uuuuuu.k....................h..iiii..........................................................",
	".....w.xxx.yyyyyyy.zzzzzz.BBBBBBBB.h..iiii..........................................................",
	"...................................h..iiiimmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm.........",
	"...................................h..iiii..........................................................",
	"...................................hlliiiixinnn.ooooo.ttt...........................................",
	"...................................h..iiiixinnn.ow.ooooo.nn.nnnnn.owCCCCC...........................",
	"...................................h..iiiixiiiooooo.nn.ooooo........................................",
	"...................................h..iiiixi........................................................",
	"...................................hlliiiixinn.owCCC.nn.CCC.........................................",
	"...................................h..iiii..xxxwwyyyyyyy.zzzzzz.z.zzz.zzzz.zzzz.zz.zzz.zzzxxxxxxxxx.",
	"...................................hlliiiixiiinnnnnn.ooooo..........................................",
	"...................................hlliiiixi........................................................",
	"...................................h..iiiixinnnnnn.owCCCwsssss.ooooo................................",
	"...................................h..iiii..........................................................",
	"...................................h..iiii..........................................................",
	"...................................h..iiiimmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm......................",
	"...................................h..iiiinnnn....ttttttt..sss...tttttt.............................",
	"...................................h..iiiiiinnnnnn.ooowsssssss.wwwwwwwww.ooooowssssss.owsssss.......",
	"...................................h..iiii..........................................................",
	"DDDDDDDDEEEEEEEEEEEEEFFFFFFEEGGGEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEHHHHIIIIJKLKKKKM",
}

T["pr: Comments tab matches the approved render"] = function()
	eq(vim.tbl_map(table.concat, H.screen_rows(child, 1, 30).text), COMMENTS_TEXT)
	H.expect_screen_colors(child, 1, COMMENTS_MASK, COMMENTS_LEGEND)
end

T["pr: Review highlight colours"] = function()
	child.cmd("colorscheme gruvbox-material")
	local p = require("gleb.colors.gruvbox-material.palette")
	for group, expected in pairs({
		PrPeek = { fg = p.foreground.fg0 },
		PrPeekAuthor = { fg = p.foreground.aqua, bold = true },
		PrPeekIcon = { fg = p.foreground.yellow },
		PrPeekMeta = { fg = p.foreground.grey1 },
		PrThreadResolved = { fg = p.foreground.grey0, italic = true },
		PrThreadOutdated = { fg = p.foreground.orange },
		ChangesTabComments = { fg = p.background.bg0, bg = p.foreground.yellow, bold = true },
	}) do
		H.expect_hl_colors(child, group, expected)
	end
end

T["pr: Editor peeks match the approved render"] = function()
	child.lua([[
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		vim.api.nvim_set_current_win(panel.editor_win)
		vim.fn.winrestview({ lnum = 18, topline = 6 })
	]])
	H.expect_screen_colors(child, 1, PEEK_MASK, PEEK_LEGEND)
end

T["pr: Resolved thread matches the approved render"] = function()
	child.lua([[
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		vim.api.nvim_set_current_win(panel.editor_win)
		vim.fn.winrestview({ lnum = 18, topline = 6 })
	]])
	H.expect_screen_colors(child, 6, vim.list_slice(PEEK_MASK, 6, 8), PEEK_LEGEND)
end

return T
