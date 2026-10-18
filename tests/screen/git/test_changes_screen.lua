-- Reference screenshots of the approved Changes panel renders (tests/screenshots/).
local F = require("tests.fixtures")
local H = require("tests.helpers")

local child = H.new_child()

local PANEL_LEGEND = {
	c = "DevIconGo",
	d = "FileTreeNormal",
	e = "FileTreeExpander",
	f = "ChangesCheckbox",
	g = "ChangesRoot",
	h = "ChangesCount",
	i = "WinSeparator",
	j = "CursorLineNr",
	k = "@keyword",
	l = "FileTreeFolderIcon",
	m = "FileTreeFolderName",
	n = "LineNr",
	o = "FileTreeCursorLine",
	p = "FileTreeGitModified",
	q = "ChangesStatAdded",
	r = "ChangesStatRemoved",
	s = "@string",
	t = "FileTreeGitAdded",
	u = "DevIconTypeScript",
	v = "@comment",
	w = "DevIconMd",
	x = "FileTreeGitUntracked",
	y = "@type",
	z = "@type.builtin",
	A = "@function",
}

local PANEL_MASK = {
	"dedfdgggggggdhhhhhhhdddddddddddddddijjjjjkkkkkkk....................................................",
	"dddedldmmmmmmmmmmmmmmmmdhddddddddddinnnnn...........................................................",
	"oooooeofocoppppppppppoooooooqqqorroinnnnnkkkkkk.....................................................",
	"dddddddddfdcdppppppppppppphdqqqdrrdinnnnn....sssss..................................................",
	"dddddedfdcdttttttdddddddddddqqqdrrdinnnnn...........................................................",
	"dddddddddfdcdtttttttttttddddqqqdrrdinnnnn....ssssssssssssssssssssssssssssssssssss...................",
	"dddedldmmmmmmmdhdddddddddddddddddddinnnnn...........................................................",
	"dddddddfdudppppppppddddddddddqqdrrdinnnnn...........................................................",
	"dedfdgggggggggggggggggdhhhhhhddddddinnnnnvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv",
	"dddddfdwdxxxxxxxxddddddddddddddddddinnnnnkkkk.yyyyyyy.kkkkkk........................................",
	"dddddddddddddddddddddddddddddddddddinnnnn....yy....zzzzzz.vvvvvvvvvvvvvvvvv.........................",
	"dddddddddddddddddddddddddddddddddddinnnnn....yyyyy...zzz............................................",
	"dddddddddddddddddddddddddddddddddddinnnnn....yyy...yyyy.............................................",
	"dddddddddddddddddddddddddddddddddddinnnnn...........................................................",
	"dddddddddddddddddddddddddddddddddddinnnnn...........................................................",
	"dddddddddddddddddddddddddddddddddddinnnnnvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv..........",
	"dddddddddddddddddddddddddddddddddddinnnnnkkkk....yyyyyyy..AAAAA...zzz...............................",
	"dddddddddddddddddddddddddddddddddddinnnnn....kkk.......zzz..........................................",
	"dddddddddddddddddddddddddddddddddddinnnnn....kkk.............kkkkk...yyyyy..........................",
	"dddddddddddddddddddddddddddddddddddinnnnn...........................................................",
	"dddddddddddddddddddddddddddddddddddinnnnn...........................................................",
	"dddddddddddddddddddddddddddddddddddinnnnn....kk...yyy....kkk........................................",
	"dddddddddddddddddddddddddddddddddddinnnnn........kkkkkk.............................................",
	"dddddddddddddddddddddddddddddddddddinnnnn...........................................................",
	"dddddddddddddddddddddddddddddddddddinnnnn....kkkkkk...yyy.AAAAA.....................................",
	"dddddddddddddddddddddddddddddddddddinnnnn...........................................................",
	"dddddddddddddddddddddddddddddddddddinnnnn...........................................................",
	"dddddddddddddddddddddddddddddddddddinnnnnvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv.......................",
}

local DIFF_LEGEND = vim.tbl_extend("force", PANEL_LEGEND, {
	j = "DiffViewHeader",
	k = "FileTreeFolderIcon",
	l = "FileTreeFolderName",
	m = "DiffViewFold",
	n = "DiffViewFoldText",
	o = "FileTreeCursorLine",
	p = "FileTreeGitModified",
	q = "ChangesStatAdded",
	r = "ChangesStatRemoved",
	s = "DiffViewLineNr",
	t = "@string",
	u = "FileTreeGitAdded",
	v = "DiffViewChange",
	w = "@comment",
	x = "DiffViewArrowChange",
	y = "DiffViewGutterChange",
	z = "DevIconTypeScript",
	A = "@keyword",
	B = "@type",
	C = "@type.builtin",
	D = "DiffViewWord",
	E = "DevIconMd",
	F = "FileTreeGitUntracked",
	G = "@function",
	H = "DiffViewPadding",
	I = "DiffViewArrowAdd",
	J = "DiffViewAdd",
	K = "DiffViewGutterAdd",
})

local DIFF_MASK = {
	"dedfdgggggggdhhhhhhhdddddddddddddddijjjjjjjjjjjjjjjjjjjjjjjjjijjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj",
	"dddedkdlllllllllllllllldhddddddddddimmnnnnnnnnnnnnnnnnnnnmmmmimmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm",
	"oooooeofocoppppppppppoooooooqqqorroi.........................i.ssss.....ssss........................",
	"dddddddddfdcdppppppppppppphdqqqdrrdi.....tttttttttttttttttttti.ssss.....ssss......tttttttttttttttttt",
	"dddddedfdcduuuuuudddddddddddqqqdrrdi.........................i.ssss.....ssss........................",
	"dddddddddfdcduuuuuuuuuuuddddqqqdrrdi.........................i.ssss.....ssss........................",
	"dddedkdllllllldhdddddddddddddddddddivwwwwwwwwwwwwwwwwwwwwwwwwixyyyyvvvvvyyyyyywwwwwwwwwwwwwwwwwwwwww",
	"dddddddfdzdppppppppddddddddddqqdrrdi.AAAA.BBBBBBB.AAAAAA.....i.ssss.....ssss..AAAA.BBBBBBB.AAAAAA...",
	"dedfdgggggggggggggggggdhhhhhhddddddivvvvvBBvvvvCCCCCCvvvvvvvvixyyyyvvvvvyyyyyyvvvvBBvvvvCCCCCCDDDDDD",
	"dddddfdEdFFFFFFFFddddddddddddddddddi.....BBBBB...CCC.........i.ssss.....ssss......BBBBB...CCC.......",
	"dddddddddddddddddddddddddddddddddddi.....BBB...BBBB..........i.ssss.....ssss......BBB...BBBB........",
	"dddddddddddddddddddddddddddddddddddi.........................i.ssss.....ssss........................",
	"dddddddddddddddddddddddddddddddddddi.........................i.ssss.....ssss........................",
	"dddddddddddddddddddddddddddddddddddi.wwwwwwwwwwwwwwwwwwwwwwwwi.ssss.....ssss..wwwwwwwwwwwwwwwwwwwwww",
	"dddddddddddddddddddddddddddddddddddi.AAAA....BBBBBBB..GGGGG..i.ssss.....ssss..AAAA....BBBBBBB..GGGGG",
	"dddddddddddddddddddddddddddddddddddivvvvvvvvvvvDDDDvvvvvvvvvvixyyyyvvvvvyyyyyyvvvvDDDvvvvvvvDDDvvvvv",
	"dddddddddddddddddddddddddddddddddddi.....AAA.............AAAAi.ssss.....ssss......AAA.............AA",
	"dddddddddddddddddddddddddddddddddddi.........................i.ssss.....ssss........................",
	"dddddddddddddddddddddddddddddddddddi.........................i.ssss.....ssss........................",
	"dddddddddddddddddddddddddddddddddddiHHHHHHHHHHHHHHHHHHHHHHHHHiIHHHHJJJJJKKKKKKJJJJAAJJJBBBJJJJAAAJJJ",
	"dddddddddddddddddddddddddddddddddddiHHHHHHHHHHHHHHHHHHHHHHHHHi.HHHHJJJJJKKKKKKJJJJJJJJAAAAAAJJJJJJJJ",
	"dddddddddddddddddddddddddddddddddddiHHHHHHHHHHHHHHHHHHHHHHHHHi.HHHHJJJJJKKKKKKJJJJJJJJJJJJJJJJJJJJJJ",
	"dddddddddddddddddddddddddddddddddddi.....AAAAAA...BBB.GGGGG..i.ssss.....ssss......AAAAAA...BBB.GGGGG",
	"dddddddddddddddddddddddddddddddddddi.........................i.ssss.....ssss........................",
	"dddddddddddddddddddddddddddddddddddi.........................i.ssss.....ssss........................",
	"dddddddddddddddddddddddddddddddddddi.wwwwwwwwwwwwwwwwwwwwwwwwi.ssss.....ssss..wwwwwwwwwwwwwwwwwwwwww",
	"dddddddddddddddddddddddddddddddddddi.AAAA....BBBBBBB..GGG...Ci.ssss.....ssss..AAAA....BBBBBBB..GGG..",
	"dddddddddddddddddddddddddddddddddddi.....AAAAAA.....GGGGGGG.ti.ssss.....ssss......AAAAAA.....GGGGGGG",
}

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
	local home = vim.fn.tempname()
	local root = F.copy("billing", vim.fs.joinpath(home, "work", "billing"))
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
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice.go")))
end

local function wait_for_panel()
	assert(
		child.wait(
			[[(function()
		local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return view ~= nil and #view.rows == 10
	end)()]],
			5000
		),
		"Changes panel did not load"
	)
	child.cmd("redraw")
end

local T = H.child_set(child, start)

T["git: Changes panel matches the approved render"] = function()
	run_action("changes.toggle")
	wait_for_panel()
	H.expect_screen_colors(child, 2, PANEL_MASK, PANEL_LEGEND)
	H.expect_screenshot(H.screen_rows(child, 2, 29))
end

T["git: Changes panel with the diff view matches the approved render"] = function()
	run_action("changes.review")
	wait_for_panel()
	assert(
		child.wait(
			[[(function()
		local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return view ~= nil and view.diff_view ~= nil
	end)()]],
			5000
		),
		"Changes diff view did not load"
	)
	child.cmd("redraw")
	H.expect_screen_colors(child, 2, DIFF_MASK, DIFF_LEGEND)
	H.expect_screenshot(H.screen_rows(child, 2, 29))
end

return T
