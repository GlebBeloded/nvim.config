local MiniTest = require("mini.test")
local H = require("tests.helpers")
local screens = require("tests.screen.pr.screens")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, function()
	screens.show_comments(child)
end)

local CONFIRM_LEGEND = {
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
	s = "FloatBorder",
	t = "FloatTitle",
	u = "ChangesCommittedFile",
	v = "PrPeekIcon",
	w = "@property",
	x = "PrPeekMeta",
	y = "PrPeekAuthor",
	z = "FileTreeCursorLine",
	A = "PrPeek",
	B = "PrConfirmHint",
	C = "PrConfirm",
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

local CONFIRM_MASK = {
	"....................................abaaaaaaaaaaaaaccccccccccccccccccccccccccccccccccccccccccccccccc",
	".ddddddddd.dddddddddd.eeeeeeeeeeee.f..gggghhhh.iiiiiii.hhhhhh.......................................",
	".jjjjjjkkkkkkkkkkkkkkkk............fllggggggii....mmmmmm.nnnnnnnnnnnnnnnnn..........................",
	".kkkkkkkkkkkkkkkkkkk...............f..gggg..ooooooooooooooooooooooooooooooooooooooooooooooooooooo...",
	"...................................f..ggggggiiiii...mmm.............................................",
	".p.q.rrrrrrrrrsttttttttttttttttttttttttttttttsssssssssssssssssssssssssssssssssssssss..............",
	"...p.b.uuuuuuus.ggggg.ghh.ivwww.hh.www...............................................s..............",
	".....v.xxx.yyys......................................................................s..............",
	"zzzzzvzxxxzyyys.yyyyyyyxxxxx.........................................................s..............",
	".....ooooooooos.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA................................snnnnn.........",
	"...p.b.uuuuuu.s.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA............................s..............",
	".....v.xxx.yyys......................................................................s..............",
	"..............s.yyyyyyyyyyyyxxxxx....................................................s..............",
	"..............s.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA................................s..............",
	"..............s.AAAAAAAAAAAAAAAAAA...................................................s..............",
	"..............s......................................................................s..............",
	"..............ssxxxxxxxsssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss.AAAxxxxxxxxx.",
	"..............s......................................................................s..............",
	"..............s......................................................................s..............",
	"..............s......................................................................s..............",
	"..............ssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss..............",
	"..............sBCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBs..............",
	"..............ssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss..............",
	"...................................f..gggghhhh....mmmmmmm..lll...mmmmmm.............................",
	"...................................f..gggggghhhhhh.iiivlllllll.vvvvvvvvv.iiiiivllllll.ivlllll.......",
	"...................................f..gggg..........................................................",
	"...................................f..gggg..........................................................",
	"...................................f..ggggnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn...................",
	"...................................f..gggghhhh....mmmmmmm..llll...mmmm..............................",
	"DDDDDDDDEEEEEEEEEEEEEFFFFFFEEGGGEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEHHHHIIIIJKLKKKKM",
}

local function padded(lines)
	return vim.tbl_map(function(line)
		return line .. string.rep(" ", 100 - vim.fn.strdisplaywidth(line))
	end, lines)
end

local CONFIRM_TEXT = padded({
	"                                     ◆ invoice.go",
	"  Local 3   Branch 4   Comments 3  ┃   12 type Invoice struct {",
	" ◆ #482 feat/tax → main            ┃┃  11 ▏ ID    string // invoice number",
	" 3 open · 1 resolved               ┃        ╰─ ◆ Resolved · ivan.p: Should ID stay a string? The…",
	"                                   ┃   10 ▏ Lines []int",
	" ▾ ◆ internal/╭ invoice.go:22 · PR #482 · open ──────────────────────────────────────╮",
	"   ▾ ◆ invoice│   22   if i.Tax == nil {                                             │",
	"     ◆ :13 iva│                                                                      │",
	"     ◆ :22 mar│ maria.k · 2h                                                         │",
	"     ◆ :11 iva│ Should a nil rate mean no tax at all?                                │rate.",
	"   ▾ ◆ tax.go │ A missing config would silently drop tax.                            │",
	"     ◆ :18 mar│                                                                      │",
	"              │ gleb-beloded · 1h                                                    │",
	"              │ Good catch, defaulting to Rate(0) and                                │",
	"              │ logging a warning.                                                   │",
	"              │                                                                      │",
	"              ├─ Reply ──────────────────────────────────────────────────────────────┤ at… +1 reply",
	"              │ Defaulting to Rate(0) now, see e325463.                              │",
	"              │                                                                      │",
	"              │                                                                      │",
	"              ├──────────────────────────────────────────────────────────────────────┤",
	"              │ Send this reply to maria.k on pgw.dev?       Send y · Keep editing n │",
	"              ╰──────────────────────────────────────────────────────────────────────╯",
	"                                   ┃    7 func (i Invoice) Due() string {",
	'                                   ┃    8 ▏ return fmt.Sprintf("due %s", money.Format(i.Total()))',
	"                                   ┃    9 }",
	"                                   ┃   10",
	"                                   ┃   11 // Paid reports whether nothing is due.",
	"                                   ┃   12 func (i Invoice) Paid() bool {",
	" NORMAL  ⎇ feat/tax  ◆ #482  ◆ 3                                                    ◆ 0 ◆ 1 ◆ ◆ go ◆",
})

local THREAD_LEGEND = vim.deepcopy(CONFIRM_LEGEND)
THREAD_LEGEND.B = "PrReplyPlaceholder"
THREAD_LEGEND.C = "PickerHint"

local THREAD_MASK = vim.deepcopy(CONFIRM_MASK)
THREAD_MASK[18] = "..............s.BBBBBBBBBBBBBB.......................................................s.............."
THREAD_MASK[22] = "..............s.......................CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC.s.............."

local THREAD_TEXT = vim.deepcopy(CONFIRM_TEXT)
THREAD_TEXT[18] = padded({ "              │ Write a reply…                                                       │              " })[1]
THREAD_TEXT[22] = padded({ "              │                       Reply ↩ · Resolve R · Open on web gx · Close q │              " })[1]

T["pr: Thread window matches the approved render"] = function()
	child.type_keys("<CR>")
	assert(child.wait([[vim.bo.filetype == "gleb-pr-thread"]], math.floor(5000 * H.load_factor())))

	local text = vim.tbl_map(function(cells)
		return H.design_text(table.concat(cells))
	end, H.screen_rows(child, 1, 30).text)
	eq(text, THREAD_TEXT)
	H.expect_screen_colors(child, 1, THREAD_MASK, THREAD_LEGEND)
end

T["pr: Send confirmation matches the approved render"] = function()
	child.type_keys("<CR>")
	assert(child.wait([[vim.bo.filetype == "gleb-pr-thread"]], math.floor(5000 * H.load_factor())))
	child.type_keys("i", "Defaulting to Rate(0) now, see e325463.", "<Esc><CR>")
	assert(child.wait([[vim.bo.filetype == "gleb-pr-confirm"]], math.floor(5000 * H.load_factor())))

	local text = vim.tbl_map(function(cells)
		return H.design_text(table.concat(cells))
	end, H.screen_rows(child, 1, 30).text)
	eq(text, CONFIRM_TEXT)
	H.expect_screen_colors(child, 1, CONFIRM_MASK, CONFIRM_LEGEND)
end

return T
