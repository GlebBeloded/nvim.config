local H = require("tests.helpers")
local cases = require("tests.render.cases")

local child = H.new_child()

local function start(case)
	child.start_config()
	child.o.lines, child.o.columns = 30, 100
	child.wait_very_lazy()
	cases[case].setup(child)
end

local T = H.child_set(child, function()
	start("diff-view")
end)

T["diff: Diff view matches the approved render"] = function()
	H.expect_screenshot(H.screen_rows(child, 2, 29))
	H.expect_screen_colors(child, 2, {
		"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		"ccddddddddddddddddddddccccccccccccccccccbccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
		"........................................b.eeee.....eeee.............................................",
		".KKKK....KFFF..UUUU....FFFFFF..FFFFF....b.eeee.....eeee..KKKK....KFFF..UUUU....FFFFFF..FFFFF........",
		".....QQQQI.QQI.QQQ.KK.QIUUUUUU.QQ.......b.eeee.....eeee......QQQQI.QQI.QQQ.KK.QIUUUUUU.QQ...........",
		".....KK.QQQ.KK.PPP......................b.eeee.....eeee......KK.QQQ.KK.PPP..........................",
		"ffffffffffffffffffffffffffffffffffffffffbghhhhfffffhhhhhhfffffffffffffffiiiiifffifffffffffffffffffff",
		"........................................b.eeee.....eeee.............................................",
		".....KK.KQQ.............................b.eeee.....eeee......KK.KQQ.................................",
		".........QQQIUUUU.IIIIIIIIIIIIIIIIIII...b.eeee.....eeee..........QQQIUUUU.IIIIIIIIIIIIIIIIIII.......",
		"........................................b.eeee.....eeee.............................................",
		"jjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjbkjjjjlllllmmmmmmlllllllllllllllllllllllllllllllllllllllllll",
		".........KKKKKK.QQQ.....................b.eeee.....eeee..........KKKKKK.QQQ.........................",
		"........................................b.eeee.....eeee.............................................",
		"........................................b.eeee.....eeee.............................................",
		".....KK.QQQ.K.QIUUU.QQQQ.I.QQQ.KK.PPP...b.eeee.....eeee......KK.QQQ.K.QIUUU.QQQQ.I.QQQ.KK.PPP.......",
		".........KKKKKK.QQQ.....................b.eeee.....eeee..........KKKKKK.QQQ.........................",
		"........................................b.eeee.....eeee.............................................",
		".....QIPPPPPIPPPPPPPIUUU................b.eeee.....eeee......QIPPPPPIPPPPPPPIUUU....................",
		"nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnboppppnnnnnjjjjqjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj",
		".....KKKKKK.PPP.........................b.eeee.....eeee......KKKKKK.PPP.............................",
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

T["diff: Diff view staged change matches the approved render"] = function()
	start("diff-view-staged")
	H.expect_screenshot(H.screen_rows(child, 2, 29))
	H.expect_screen_colors(child, 2, {
		"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		"ccddddddddddddddddddddccccccccccccccccccbccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
		"........................................b.eeee.....eeee.............................................",
		".KKKK....KFFF..UUUU....FFFFFF..FFFFF....b.eeee.....eeee..KKKK....KFFF..UUUU....FFFFFF..FFFFF........",
		".....QQQQI.QQI.QQQ.KK.QIUUUUUU.QQ.......b.eeee.....eeee......QQQQI.QQI.QQQ.KK.QIUUUUUU.QQ...........",
		".....KK.QQQ.KK.PPP......................b.eeee.....eeee......KK.QQQ.KK.PPP..........................",
		"ffffffffffffffffffffffffffffffffffffffffbghhhhfffffhhhhhhfffffffffffffffiiiiifffifffffffffffffffffff",
		"........................................b.eeee.....eeee.............................................",
		".....KK.KQQ.............................b.eeee.....eeee......KK.KQQ.................................",
		".........QQQIUUUU.IIIIIIIIIIIIIIIIIII...b.eeee.....eeee..........QQQIUUUU.IIIIIIIIIIIIIIIIIII.......",
		"........................................b.eeee.....eeee.............................................",
		"jjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjbkjjjjlllllmmmmmmlllllllllllllllllllllllllllllllllllllllllll",
		".........KKKKKK.QQQ.....................b.eeee.....eeee..........KKKKKK.QQQ.........................",
		"........................................b.eeee.....eeee.............................................",
		"........................................b.eeee.....eeee.............................................",
		".....KK.QQQ.K.QIUUU.QQQQ.I.QQQ.KK.PPP...b.eeee.....eeee......KK.QQQ.K.QIUUU.QQQQ.I.QQQ.KK.PPP.......",
		".........KKKKKK.QQQ.....................b.eeee.....eeee..........KKKKKK.QQQ.........................",
		"........................................b.eeee.....eeee.............................................",
		".....QIPPPPPIPPPPPPPIUUU................b.eeee.....eeee......QIPPPPPIPPPPPPPIUUU....................",
		"nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnboppppnnnnnjjjjqjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj",
		".....KKKKKK.PPP.........................b.eeee.....eeee......KKKKKK.PPP.............................",
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
		F = "@function.call",
		I = "@punctuation.delimiter",
		K = "@keyword",
		P = "@property",
		Q = "@variable.member",
		U = "@function",
	})
end

T["diff: Diff view moved block matches the approved render"] = function()
	start("diff-view-moved")
	H.expect_screenshot(H.screen_rows(child, 2, 29))
	H.expect_screen_colors(child, 2, {
		"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		".KKKKKKK................................b.cccc.....cccc..KKKKKKK....................................",
		"........................................b.cccc.....cccc.............................................",
		"dCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCdddddddddbeffffggggghhhhihhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh",
		"ddddddddddddddddddddddddddddddddddddddddb.ffffdddddhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh",
		"ddddddddddddddddddddddddddddddddddddddddb.ffffdddddhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh",
		"ddddddddddddddddddddddddddddddddddddddddb.ffffdddddhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh",
		"ddddddddddddddddddddddddddddddddddddddddb.ffffdddddhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh",
		"ddddddddddddddddddddddddddddddddddddddddb.ffffdddddhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh",
		"ddddddddddddddddddddddddddddddddddddddddb.ffffdddddhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh",
		".CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCb.cccc.....cccc..CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC...",
		".KKKK.UUUUUUUUU....TTTTTT..TTTTTT.......b.cccc.....cccc..KKKK.UUUUUUUUU....TTTTTT..TTTTTT...........",
		".....KKKKKK.VVVVVVVIUUUUUUU.VVVVVVVIUUUUb.cccc.....cccc......KKKKKK.VVVVVVVIUUUUUUU.VVVVVVVIUUUUUUUU",
		"........................................b.cccc.....cccc.............................................",
		".CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC....b.cccc.....cccc..CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC........",
		".KKKK.UUU....TTTTTT..TTTTTT.............b.cccc.....cccc..KKKK.UUU....TTTTTT..TTTTTT.................",
		".....KKKKKK.IIIIIII.K.TTTTTTTTT.VV......b.cccc.....cccc......KKKKKK.IIIIIII.K.TTTTTTTTT.VV..........",
		"........................................b.cccc.....cccc.............................................",
		"hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhbjhhhhgggggffffffCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCddddddddddddd",
		"hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhb.hhhhdddddffffffddddddddddddddddddddddddddddddddddddddddddd",
		"hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhb.hhhhdddddffffffddddddddddddddddddddddddddddddddddddddddddd",
		"hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhb.hhhhdddddffffffddddddddddddddddddddddddddddddddddddddddddd",
		"hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhb.hhhhdddddffffffddddddddddddddddddddddddddddddddddddddddddd",
		"hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhb.hhhhdddddffffffddddddddddddddddddddddddddddddddddddddddddd",
		"hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhb.hhhhdddddffffffddddddddddddddddddddddddddddddddddddddddddd",
		"........................................b...........................................................",
		"........................................b...........................................................",
		"........................................b...........................................................",
	}, {
		a = "DiffViewHeader",
		b = "WinSeparator",
		c = "DiffViewLineNr",
		d = "DiffViewMoved",
		e = "DiffViewArrowDelete",
		f = "DiffViewGutterMoved",
		g = "DiffViewMovedMarker",
		h = "DiffViewPadding",
		i = "DiffViewCheckbox",
		j = "DiffViewArrowAdd",
		C = "@comment",
		I = "@punctuation.delimiter",
		K = "@keyword",
		O = "@operator",
		S = "@string",
		T = "@type.builtin",
		U = "@function",
		V = "@variable.go",
	})
end

return T
