local MiniTest = require("mini.test")
local H = require("tests.helpers")
local cases = require("tests.render.cases")

local child = H.new_child()

local function start()
	child.start_config()
	child.o.lines, child.o.columns = 30, 100
	child.wait_very_lazy()
	cases["diff-view"].setup(child)
end

local T = H.child_set(child, start)

T["diff: Diff view matches the approved render"] = function()
	H.expect_screenshot(H.screen_rows(child, 2, 29))
	H.expect_screen_colors(child, 2, {
		"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		"ccddddddddddddddddddddccccccccccccccccccbccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
		"........................................b.eeee.....eeee.............................................",
		".KKKK....KFFF..UUUU....FFFFFF..FFFFF....b.eeee.....eeee..KKKK....KFFF..UUUU....FFFFFF..FFFFF........",
		"...QQQQI.QQI.QQQ.KK.QIUUUUUU.QQ.........b.eeee.....eeee......QQQQI.QQI.QQQ.KK.QIUUUUUU.QQ...........",
		"...KK.QQQ.KK.PPP........................b.eeee.....eeee......KK.QQQ.KK.PPP..........................",
		"ffffffffffffffffffffffffffffffffffffffffbghhhhfffffhhhhhhfffffffffffffffiiiiifffifffffffffffffffffff",
		"........................................b.eeee.....eeee.............................................",
		"...KK.KQQ...............................b.eeee.....eeee......KK.KQQ.................................",
		".....QQQIUUUU.IIIIIIIIIIIIIIIIIII.......b.eeee.....eeee..........QQQIUUUU.IIIIIIIIIIIIIIIIIII.......",
		"........................................b.eeee.....eeee.............................................",
		"jjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjbkjjjjlllllmmmmmmlllllllllllllllllllllllllllllllllllllllllll",
		".....KKKKKK.QQQ.........................b.eeee.....eeee..........KKKKKK.QQQ.........................",
		"........................................b.eeee.....eeee.............................................",
		"........................................b.eeee.....eeee.............................................",
		"...KK.QQQ.K.QIUUU.QQQQ.I.QQQ.KK.PPP.....b.eeee.....eeee......KK.QQQ.K.QIUUU.QQQQ.I.QQQ.KK.PPP.......",
		".....KKKKKK.QQQ.........................b.eeee.....eeee..........KKKKKK.QQQ.........................",
		"........................................b.eeee.....eeee.............................................",
		"...QIPPPPPIPPPPPPPIUUU..................b.eeee.....eeee......QIPPPPPIPPPPPPPIUUU....................",
		"nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnboppppnnnnnjjjjqjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj",
		"...KKKKKK.PPP...........................b.eeee.....eeee......KKKKKK.PPP.............................",
		"........................................b.eeee.....eeee.............................................",
		"........................................b.eeee.....eeee.............................................",
		".KKKK....KFFF..UUUUU...FFFFF............b.eeee.....eeee..KKKK....KFFF..UUUUU...FFFFF................",
		"ccddddddddddddddddddddccccccccccccccccccbccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
		"........................................b...........................................................",
		"........................................b...........................................................",
		"........................................b...........................................................",
	}, {
		a = "DiffViewHeader",
		b = "WinSeparator",
		c = "DiffViewFold",
		d = "DiffViewFoldText",
		e = "DiffViewLineNr",
		f = "DiffViewChange",
		g = "DiffViewArrowChange",
		h = "DiffViewGutterChange",
		i = "DiffViewWord",
		j = "DiffViewPadding",
		k = "DiffViewArrowAdd",
		l = "DiffViewAdd",
		m = "DiffViewGutterAdd",
		n = "DiffViewDelete",
		o = "DiffViewArrowDelete",
		p = "DiffViewGutterDelete",
		q = "DiffViewCheckbox",
		B = "@punctuation.bracket.go",
		F = "@function.call",
		I = "@punctuation.delimiter",
		K = "@keyword",
		M = "@module.go",
		O = "@operator",
		P = "@property",
		Q = "@variable.member",
		T = "@type.builtin",
		U = "@function",
		V = "@variable.go",
		Y = "@type",
	})
end

return T
