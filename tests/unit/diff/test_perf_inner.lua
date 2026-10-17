local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
end

local T = H.child_set(child, start)

T["diff: Inner ranges for 500 changed lines stay within budget"] = function()
	local result = child.lua_get([[(function()
		local engine = require("gleb.diff.engine")
		local lines1 = {}
		local lines2 = {}
		for index = 1, 5000 do
			local line
			if index % 10 == 0 then
				line = ""
			elseif index % 10 == 9 then
				line = "end"
			else
				line = string.format('local value_%d = compute(%d, "item %d")', index, index * 7, index)
			end
			lines1[index] = line
			lines2[index] = index % 10 == 5 and line:gsub("compute", "calculate") or line
		end

		engine.compare_lines(lines1, lines2, { highlight = "by_word" })
		local samples = {}
		local comparison
		for run = 1, 3 do
			local started = vim.uv.hrtime()
			comparison = engine.compare_lines(lines1, lines2, { highlight = "by_word" })
			samples[run] = (vim.uv.hrtime() - started) / 1e6
		end
		table.sort(samples)
		local inner_counts = {}
		for _, fragment in ipairs(comparison.fragments) do
			inner_counts[#inner_counts + 1] = fragment.inner and #fragment.inner or -1
		end
		return { count = #comparison.fragments, inner_counts = inner_counts, median_ms = samples[2] }
	end)()]])
	eq(result.count, 500)
	eq(result.inner_counts, vim.fn["repeat"]({ 1 }, 500))
	eq(result.median_ms < 200 * H.load_factor(), true, {
		fail_reason = ("median %.1f ms exceeded budget"):format(result.median_ms),
	})
end

return T
