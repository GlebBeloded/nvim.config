local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
end

local T = H.child_set(child, start)

T["diff: A 5000-line file compares within budget"] = function()
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
			if index % 100 == 55 then
				line = line:gsub("compute", "calculate")
			end
			lines2[#lines2 + 1] = line
			if index % 500 == 1 then
				lines2[#lines2 + 1] = "-- inserted"
			end
			if index % 500 == 275 then
				table.remove(lines2)
			end
		end

		engine.compare_lines(lines1, lines2)
		local samples = {}
		local result
		for run = 1, 3 do
			local started = vim.uv.hrtime()
			result = engine.compare_lines(lines1, lines2)
			samples[run] = (vim.uv.hrtime() - started) / 1e6
		end
		table.sort(samples)
		return {
			count = #result.fragments,
			median_ms = samples[2],
			too_big = result.too_big,
			timed_out = result.timed_out,
		}
	end)()]])
	eq(result.count, 70)
	eq(result.too_big, false)
	eq(result.timed_out, false)
	eq(result.median_ms < 100 * H.load_factor(), true, {
		fail_reason = ("median %.1f ms exceeded budget"):format(result.median_ms),
	})
end

T["diff: A 100000-line suffix edit meets deadline"] = function()
	local result = child.lua_get([[(function()
		local engine = require("gleb.diff.engine")
		local lines1 = {}
		local lines2 = {}
		for index = 1, 100000 do
			local line = "line " .. index
			lines1[index] = line
			lines2[index] = line
		end
		lines2[100000] = "changed"
		local started = vim.uv.hrtime()
		local comparison = engine.compare_lines(lines1, lines2)
		return {
			count = #comparison.fragments,
			elapsed_ms = (vim.uv.hrtime() - started) / 1e6,
			too_big = comparison.too_big,
			timed_out = comparison.timed_out,
		}
	end)()]])
	eq(result.count, 1)
	eq(result.too_big, false)
	eq(result.timed_out, false)
	eq(result.elapsed_ms < 1000, true, {
		fail_reason = ("suffix edit took %.1f ms"):format(result.elapsed_ms),
	})
end

return T
