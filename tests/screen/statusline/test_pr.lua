local MiniTest = require("mini.test")
local H = require("tests.helpers")
local screens = require("tests.screen.pr.screens")

local child = H.new_child()

local T = H.child_set(child, function()
	screens.show_comments(child)
	screens.show_peeks(child)
end)

T["statusline: Statusline with a pull request matches the approved render"] = function()
	MiniTest.expect.equality(
		H.design_text(table.concat(H.screen_rows(child, -1).text[1])),
		" NORMAL  ⎇ feat/tax  ◆ #482  ◆ 3                                                    ◆ 0 ◆ 1 ◆ ◆ go ◆"
	)
	H.expect_screen_colors(child, -1, {
		"aaaaaaaabbbbbbbbbbbbbccccccbbdddbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbeeeeeffffghihhhhj",
	}, {
		a = "lualine_a_normal",
		b = "lualine_b_normal",
		c = "PrStatuslineNumber",
		d = "PrStatuslineThreads",
		e = "lualine_x_diagnostics_error_normal",
		f = "lualine_x_diagnostics_warn_normal",
		g = "StatuslineLangCapOk",
		h = "StatuslineLangText",
		i = "StatuslineLang_go",
		j = "StatuslineLangEdge",
	})
end

return T
