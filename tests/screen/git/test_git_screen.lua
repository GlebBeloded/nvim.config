-- Reference screenshot of the buffer rows with a gitsigns hunk (tests/screenshots/).
-- Update with `make screenshots` (UPDATE_SCREENSHOTS=1) after an intended change.
local MiniTest = require("mini.test")
local H = require("tests.helpers")
local cases = require("tests.render.cases")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_config()
	child.o.lines, child.o.columns = 8, 60
	child.wait_very_lazy()
	cases["git-hunk"].setup(child)
end

local T = H.child_set(child, start)

T["git: Added line sign matches reference screenshot"] = function()
	-- screen row 3 is buffer line 2 (row 1 is the bufferline)
	eq(H.screen_rows(child, 3).text[1][1], "┃")
	H.expect_screen_colors(child, 2, {
		"..nnnnkkkkk.c.o.............................................",
		"aannnncdf.o.p...............................................",
		"..nnnn......................................................",
		"..nnnnrrrrrr.c..............................................",
	}, {
		a = "GitSignsAdd",
		n = "LineNr",
		k = "@keyword",
		c = "@constant",
		o = "@operator",
		d = "@punctuation.delimiter",
		f = "@variable.member",
		p = "@number",
		r = "@keyword.return",
	})
	H.expect_screenshot(H.screen_rows(child, 2, 5))
end

return T
