local H = require("tests.helpers")
local cases = require("tests.render.cases")

local child = H.new_child()

local function start()
	child.start_config()
	child.o.lines, child.o.columns = 30, 100
	child.wait_very_lazy()
	cases["committed-signs"].setup(child)
end

local T = H.child_set(child, start)

T["git: Committed signs match the approved render"] = function()
	H.expect_screenshot(H.screen_rows(child, 2, 28))
	H.expect_screen_colors(child, 2, {
		"..eeeefffffff.......................................................................................",
		"..eeee..............................................................................................",
		"..eeeeffffff.g......................................................................................",
		"..eeeeh.iiiii.......................................................................................",
		"..eeeeh.............................................................................................",
		"..eeeeh.iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii........................................................",
		"..eeeeg.............................................................................................",
		"..eeee..............................................................................................",
		"..eeeejj.jjjjjjj.jj.j.jjjj.jj.jjjj.jjjjjjj.jj.jjjjjj................................................",
		"..eeeekkkk.lllllll.kkkkkk.g.........................................................................",
		"mmeeeeh.nn....oooooo.jj.jjjjjjj.jjjjjj..............................................................",
		"..eeeeh.nnnnn.ggooo.................................................................................",
		"ppeeeeh.nnn...qqqq..................................................................................",
		"..eeeeg.............................................................................................",
		"..eeee..............................................................................................",
		"..eeeejj.jjjjj.jjjj.jjj.jjjjj.jjj.jjjjjjj.jjj.jjj.jjjjj.............................................",
		"..eeeerrrr.gs.qqqqqqqg.tttttgg.ooo.g................................................................",
		"ppeeeeh.kkk.uuuuu.ooo...............................................................................",
		"..eeeeh.vvv.uw.uuuuu.xx.kkkkk.uwyyyyy.g.............................................................",
		"..eeeeh.h.uuuuu.xx.uuuuu............................................................................",
		"..eeeeh.g...........................................................................................",
		"ppeeeeh.zz.uwyyy.xx.AAA.g...........................................................................",
		"ppeeeeh.h.BBBBBB.uuuuu..............................................................................",
		"ppeeeeh.g...........................................................................................",
		"..eeeeh.BBBBBB.uwyyywCCCCCguuuuug...................................................................",
		"..eeeeg.............................................................................................",
		"..eeee..............................................................................................",
		"..eeeejj.jjj.jjjjjjj.jjj.jjjjj.jj.jjjjjjjj..........................................................",
	}, {
		a = "BufferLineIndicatorSelected",
		b = "BufferLineBufferSelected",
		c = "DevIconGo",
		d = "BufferLineFill",
		e = "LineNr",
		f = "@keyword.import",
		g = "@punctuation.bracket",
		h = "IblIndent",
		i = "@string",
		j = "@comment",
		k = "@keyword",
		l = "@type.definition",
		m = "GitSignsChange",
		n = "@variable.member",
		o = "@type.builtin",
		p = "GitCommittedSign",
		q = "@type",
		r = "@keyword.function",
		s = "@variable.parameter",
		t = "@function.method",
		u = "@variable",
		v = "@keyword.repeat",
		w = "@punctuation.delimiter",
		x = "@operator",
		y = "@property",
		z = "@keyword.conditional",
		A = "@character",
		B = "@keyword.return",
		C = "@function.method.call",
	}, { columns = 6 })
end

return T
