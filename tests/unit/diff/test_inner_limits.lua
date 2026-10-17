local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
end

local T = H.child_set(child, start)

T["diff: Inner comparison stops after three failures"] = function()
	local fragments = child.lua_get([[
		require("gleb.diff.engine").compare_lines(
			{ "aaaaaaa1", "same one", "aaaaaaa2", "same two", "aaaaaaa3", "same three", "x y" },
			{ "bbbbbbb1", "same one", "bbbbbbb2", "same two", "bbbbbbb3", "same three", "x z" },
			{ limits = { max_inner_bytes = 4 } }
		).fragments
	]])
	eq(#fragments, 4)
	for _, fragment in ipairs(fragments) do
		eq(fragment.inner, nil)
	end
end

T["diff: Small fragments keep inner ranges after two failures"] = function()
	local fragments = child.lua_get([[
		require("gleb.diff.engine").compare_lines(
			{ "aaaaaaa1", "same one", "aaaaaaa2", "same two", "x y" },
			{ "bbbbbbb1", "same one", "bbbbbbb2", "same two", "x z" },
			{ limits = { max_inner_bytes = 4 } }
		).fragments
	]])
	eq(fragments, {
		{ start1 = 0, end1 = 1, start2 = 0, end2 = 1 },
		{ start1 = 2, end1 = 3, start2 = 2, end2 = 3 },
		{
			start1 = 4,
			end1 = 5,
			start2 = 4,
			end2 = 5,
			inner = { { start1 = 2, end1 = 3, start2 = 2, end2 = 3 } },
		},
	})
end

T["diff: A deadline during inner comparison keeps the line diff"] = function()
	local result = child.lua_get([[(function()
		local now = 0
		local by_word = require("gleb.diff.engine.by_word")
		local original = by_word.compare_and_split
		local comparisons = 0
		by_word.compare_and_split = function(...)
			comparisons = comparisons + 1
			if comparisons == 3 then now = 5000 end
			return original(...)
		end
		local comparison = require("gleb.diff.engine").compare_lines(
			{ "alpha one", "keep a", "bravo two", "keep b", "charlie three" },
			{ "alpha 1", "keep a", "bravo 2", "keep b", "charlie 3" },
			{ limits = { timeout_ms = 1000, clock = function() return now end } }
		)
		by_word.compare_and_split = original
		return comparison
	end)()]])
	eq(result.timed_out, true)
	eq(
		vim.tbl_map(function(fragment)
			return { fragment.start1, fragment.end1, fragment.start2, fragment.end2 }
		end, result.fragments),
		{
			{ 0, 1, 0, 1 },
			{ 2, 3, 2, 3 },
			{ 4, 5, 4, 5 },
		}
	)
	eq(result.fragments[3].inner, nil)
end

return T
