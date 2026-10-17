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
		local fragments
		for run = 1, 3 do
			local started = vim.uv.hrtime()
			fragments = engine.compare_lines(lines1, lines2).fragments
			samples[run] = (vim.uv.hrtime() - started) / 1e6
		end
		table.sort(samples)
		return { count = #fragments, median_ms = samples[2] }
	end)()]])
	eq(result.count, 70)
	eq(result.median_ms < 100 * H.load_factor(), true, {
		fail_reason = ("median %.1f ms exceeded budget"):format(result.median_ms),
	})
end

return T
