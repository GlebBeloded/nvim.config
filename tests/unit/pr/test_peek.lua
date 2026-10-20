local MiniTest = require("mini.test")

local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

T["pr: Peek text is cut at a word boundary"] = function()
	local ok, peek = pcall(require, "gleb.pr.peek")
	eq(ok, true)
	local truncate = peek.truncate
	local text = "Should a nil rate mean no tax at all?\nA missing config would silently drop tax."
	eq(truncate(text, 34), "Should a nil rate mean no tax at…")
	eq(truncate(text, 40), "Should a nil rate mean no tax at all?")
	eq(truncate("Rate or *Rate here?", 16), "Rate or *Rate…")
	eq(truncate("Supercalifragilistic", 8), "Superca…")
	eq(truncate("anything", 0), "")
end

return T
