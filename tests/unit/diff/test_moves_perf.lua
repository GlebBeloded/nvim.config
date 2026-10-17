local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
end

local T = H.child_set(child, start)

T["diff: Move detection on a 5000-line file stays within budget"] = function()
	local result = child.lua_get([[(function()
		local engine = require("gleb.diff.engine")
		local lines1 = {}
		for index = 1, 5000 do
			if index % 10 == 0 then
				lines1[index] = ""
			elseif index % 10 == 9 then
				lines1[index] = "end"
			else
				lines1[index] = string.format('local value_%d = compute(%d, "item %d")', index, index * 7, index)
			end
		end

		local lines2 = {}
		for index, line in ipairs(lines1) do
			if index < 2101 or index > 2140 then lines2[#lines2 + 1] = line end
		end
		for index = 2101, 2140 do
			lines2[#lines2 + 1] = lines1[index]
		end

		engine.compare_lines(lines1, lines2, { moves = true })
		local samples = {}
		local comparison
		for run = 1, 3 do
			local started = vim.uv.hrtime()
			comparison = engine.compare_lines(lines1, lines2, { moves = true })
			samples[run] = (vim.uv.hrtime() - started) / 1e6
		end
		table.sort(samples)
		return {
			median_ms = samples[2],
			moves = comparison.moves,
			timed_out = comparison.timed_out,
			too_big = comparison.too_big,
		}
	end)()]])

	eq(#result.moves, 1)
	eq(result.moves[1].end1 - result.moves[1].start1, 40)
	eq(result.moves[1].end2 - result.moves[1].start2, 40)
	eq(result.moves[1].fragments, {})
	eq(result.timed_out, false)
	eq(result.too_big, false)
	eq(result.median_ms < 150 * H.load_factor(), true, {
		fail_reason = ("median %.1f ms exceeded budget"):format(result.median_ms),
	})
end

T["diff: Reindented blocks respect the move deadline"] = function()
	local result = child.lua_get([[(function()
		local lines1 = {}
		local lines2 = {}
		for index = 1, 2000 do
			lines1[index] = "}"
			lines2[index] = "  }"
		end
		local started = vim.uv.hrtime()
		local comparison = require("gleb.diff.engine").compare_lines(lines1, lines2, { moves = true })
		return {
			elapsed_ms = (vim.uv.hrtime() - started) / 1e6,
			moves = comparison.moves,
			timed_out = comparison.timed_out,
			too_big = comparison.too_big,
		}
	end)()]])

	local fast = result.elapsed_ms < 150 * H.load_factor()
	local clean_timeout = result.elapsed_ms < 1200 * H.load_factor()
		and result.timed_out
		and not result.too_big
		and #result.moves == 0
	eq(fast or clean_timeout, true, {
		fail_reason = ("%.1f ms neither completed within budget nor timed out cleanly"):format(result.elapsed_ms),
	})
end

return T
