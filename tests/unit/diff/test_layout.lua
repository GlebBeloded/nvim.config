local MiniTest = require("mini.test")

local eq = MiniTest.expect.equality
local loaded, layout = pcall(require, "gleb.diff.view.layout")

local fragments = {
	{ start1 = 52, end1 = 53, start2 = 52, end2 = 53 },
	{ start1 = 57, end1 = 57, start2 = 57, end2 = 58 },
	{ start1 = 64, end1 = 65, start2 = 65, end2 = 65 },
}

local function controller_layout()
	eq(loaded, true)
	return layout.build(fragments, 151, 151, 4)
end

local T = MiniTest.new_set()

T["diff: Diff view pads the side without lines"] = MiniTest.new_set()

T["diff: Diff view pads the side without lines"]["aligns all three controller changes"] = function()
	local result = controller_layout()
	eq(#result.rows, 24)
	eq(result.rows[6], { left = 53, right = 53, change = 1, kind = "Change", first = true, checkbox = true })
	eq(result.rows[11], { right = 58, change = 2, kind = "Add", first = true, checkbox = true })
	eq(result.rows[12], { left = 58, right = 59 })
	eq(result.rows[18], { left = 64, right = 65 })
	eq(result.rows[19], { left = 65, change = 3, kind = "Delete", first = true, checkbox = true })
	eq(result.rows[20], { left = 66, right = 66 })
end

T["diff: Diff view pads the side without lines"]["pads above the first line"] = function()
	eq(loaded, true)
	local result = layout.build({ { start1 = 0, end1 = 0, start2 = 0, end2 = 1 } }, 1, 2, 4)
	eq(result.rows, {
		{ right = 1, change = 1, kind = "Add", first = true, checkbox = true },
		{ left = 1, right = 2 },
	})
end

T["diff: Diff view folds unchanged lines with context 4"] = function()
	local result = controller_layout()
	eq(result.folds, {
		{ row = 1, start1 = 1, end1 = 48, start2 = 1, end2 = 48, count = 48 },
		{ row = 24, start1 = 70, end1 = 151, start2 = 70, end2 = 151, count = 82 },
	})
	eq(result.rows[1], {
		fold = 1,
		left = 1,
		right = 1,
		count = 48,
	})
	eq(result.rows[2], { left = 49, right = 49 })
	eq(result.rows[23], { left = 69, right = 69 })
	eq(result.rows[24], {
		fold = 2,
		left = 70,
		right = 70,
		count = 82,
	})
end

T["diff: Diff view maps the cursor across changes"] = function()
	local result = controller_layout()
	eq(layout.transfer_line(result, "right", 58), 58)
	eq(layout.transfer_line(result, "right", 59), 58)
	eq(layout.transfer_line(result, "left", 65), 66)
	eq(layout.change_at_line(result, "left", 58), 2)
end

T["diff: Diff view gutter shows both line numbers"] = MiniTest.new_set()

T["diff: Diff view gutter shows both line numbers"]["formats unchanged, changed and padded rows"] = function()
	local result = controller_layout()
	eq(layout.gutter(result.rows[5]), "  52       52   ")
	eq(layout.gutter(result.rows[6]), "» 53       53 ☐ ")
	eq(layout.gutter(result.rows[11]), "»╱╱╱╱      58 ☐ ")
end

T["diff: Diff view gutter shows both line numbers"]["omits the checkbox for a file absent from HEAD"] = function()
	eq(loaded, true)
	local result = layout.build({ { start1 = 0, end1 = 0, start2 = 0, end2 = 1 } }, 0, 1, 4)
	eq(layout.gutter(result.rows[1]), "»╱╱╱╱       1   ")
end

return T
