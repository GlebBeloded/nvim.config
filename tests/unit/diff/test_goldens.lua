local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		IntellijLines = dofile("tests/unit/diff/fixtures/intellij_lines.lua")
		IntellijEquality = dofile("tests/unit/diff/fixtures/intellij_equality.lua")
		DiffbanditOracle = dofile("tests/unit/diff/fixtures/diffbandit_oracle.lua")

		local function load_engine(source)
			local ok, engine = pcall(require, "gleb.diff.engine")
			if not ok then return nil, source .. ": " .. tostring(engine) end
			return engine, nil
		end

		local function fragments(result)
			return vim.tbl_map(function(fragment)
				return { fragment.start1, fragment.end1, fragment.start2, fragment.end2 }
			end, result.fragments)
		end

		local function changed(result, side)
			local indexes = {}
			for _, fragment in ipairs(result.fragments) do
				for index = fragment["start" .. side], fragment["end" .. side] - 1 do
					table.insert(indexes, index)
				end
			end
			return indexes
		end

		function RunIntellijLines()
			for _, row in ipairs(IntellijLines) do
				local engine, load_error = load_engine(row.source)
				if load_error then return load_error end
				for policy, expected in pairs(row.expect) do
					local result = engine.compare_lines(row.lines1, row.lines2, { policy = policy })
					if result.too_big or result.timed_out then
						return row.source .. " (" .. policy .. ") used fallback"
					end
					if expected.fragments and not vim.deep_equal(fragments(result), expected.fragments) then
						return row.source .. " (" .. policy .. ") fragments: " .. vim.inspect(fragments(result))
					end
					if expected.changed1 and not vim.deep_equal(changed(result, 1), expected.changed1) then
						return row.source .. " (" .. policy .. ") changed1: " .. vim.inspect(changed(result, 1))
					end
					if expected.changed2 and not vim.deep_equal(changed(result, 2), expected.changed2) then
						return row.source .. " (" .. policy .. ") changed2: " .. vim.inspect(changed(result, 2))
					end
				end
			end
			return true
		end

		function RunIntellijEquality()
			for _, row in ipairs(IntellijEquality) do
				local engine, load_error = load_engine(row.source)
				if load_error then return load_error end
				local policy = row.kind == "trim_equality" and "trim_whitespaces" or "default"
				local result = engine.compare_lines(row.lines1, row.lines2, { policy = policy })
				if result.too_big or result.timed_out then return row.source .. ": used fallback" end
				local actual = fragments(result)
				local expected
				if row.kind == "trim_equality" then
					actual = #actual == 0
					expected = row.equal
				else
					expected = row.fragments
				end
				if not vim.deep_equal(actual, expected) then
					return row.source .. ": " .. vim.inspect(actual)
				end
			end
			return true
		end

		function RunDiffbanditOracle()
			for _, row in ipairs(DiffbanditOracle) do
				local engine, load_error = load_engine(row.source)
				if load_error then return load_error end
				local result = engine.compare_lines(row.lines1, row.lines2)
				if result.too_big or result.timed_out then return row.source .. ": used fallback" end
				local actual = fragments(result)
				if not vim.deep_equal(actual, row.fragments) then
					return row.source .. ": " .. vim.inspect(actual)
				end
			end
			return true
		end
	]])
end

local T = H.child_set(child, start)

T["diff: Every IntelliJ line case passes"] = function()
	eq(child.lua_get("#IntellijLines"), 69)
	eq(child.lua_get("RunIntellijLines()"), true)
end

T["diff: IntelliJ trim equality and line fragments hold"] = function()
	eq(child.lua_get("#IntellijEquality"), 45)
	eq(child.lua_get("RunIntellijEquality()"), true)
end

T["diff: diffbandit oracle goldens pass"] = function()
	eq(child.lua_get("#DiffbanditOracle"), 5)
	eq(child.lua_get("RunDiffbanditOracle()"), true)
end

return T
