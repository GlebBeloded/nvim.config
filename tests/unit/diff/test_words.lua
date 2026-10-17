local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		function CompareWords(text1, text2, opts)
			return require("gleb.diff.engine").compare_words(text1, text2, opts)
		end
		function ChangedBytes(fragments, side)
			local result = {}
			for _, fragment in ipairs(fragments) do
				for offset = fragment["start" .. side], fragment["end" .. side] - 1 do
					result[#result + 1] = offset
				end
			end
			return result
		end
	]])
end

local T = H.child_set(child, start)

T["diff: CJK characters are words of their own"] = function()
	local fragments = child.lua_get([[CompareWords("汉语漢語", "語汉语漢")]])
	eq(child.lua_get([[ChangedBytes(..., 1)]], { fragments }), { 9, 10, 11 })
	eq(child.lua_get([[ChangedBytes(..., 2)]], { fragments }), { 0, 1, 2 })
end

T["diff: Punctuation separates words"] = function()
	eq(child.lua_get([[CompareWords("x,y", "x")]]), {
		{ start1 = 1, end1 = 3, start2 = 1, end2 = 1 },
	})
end

return T
