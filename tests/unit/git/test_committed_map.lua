local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

local function entries(kinds)
	local result = {}
	for line, kind in pairs(kinds) do
		table.insert(result, { line, kind })
	end
	table.sort(result, function(a, b)
		return a[1] < b[1]
	end)
	return result
end

T["git: Committed signs kinds and mapping follow the unit table"] = MiniTest.new_set()

T["git: Committed signs kinds and mapping follow the unit table"]["classifies and maps every approved row"] = function()
	local rows = {
		{
			{ "a", "b", "c", "d" },
			{ "a", "B", "c", "x", "d" },
			{ "a", "B", "c", "x", "d" },
			{ [2] = "change", [4] = "add" },
			{ [2] = "change", [4] = "add" },
		},
		{
			{ "a", "b", "c", "d" },
			{ "a", "d" },
			{ "a", "d" },
			{ [1] = "delete" },
			{ [1] = "delete" },
		},
		{
			{ "a", "b" },
			{ "b" },
			{ "b" },
			{ [1] = "topdelete" },
			{ [1] = "topdelete" },
		},
		{
			{ "a", "b", "c", "d" },
			{ "a", "X", "d" },
			{ "a", "X", "d" },
			{ [2] = "changedelete" },
			{ [2] = "changedelete" },
		},
		{
			{ "a", "b", "c", "d" },
			{ "a", "B", "c", "x", "d" },
			{ "new", "a", "B", "c", "x", "d" },
			{ [2] = "change", [4] = "add" },
			{ [3] = "change", [5] = "add" },
		},
		{
			{ "a", "b", "c", "d" },
			{ "a", "B", "c", "x", "d" },
			{ "a", "B2", "c", "x", "d" },
			{ [2] = "change", [4] = "add" },
			{ [4] = "add" },
		},
		{
			{ "a", "b", "c", "d" },
			{ "a", "B", "c", "x", "d" },
			{ "a", "B", "x", "d" },
			{ [2] = "change", [4] = "add" },
			{ [2] = "change", [3] = "add" },
		},
		{
			{ "a", "b", "c", "d" },
			{ "a", "B", "c", "x", "d" },
			{ "a", "B", "c", "x", "d", "tail" },
			{ [2] = "change", [4] = "add" },
			{ [2] = "change", [4] = "add" },
		},
	}

	eq(
		child.lua(
			[[local map, rows = require("gleb.git.committed_signs.map"), ...
			local function entries(kinds)
				local result = {}
				for line, kind in pairs(kinds) do table.insert(result, { line, kind }) end
				table.sort(result, function(a, b) return a[1] < b[1] end)
				return result
			end
			local out = {}
			for i, row in ipairs(rows) do
				local kinds = map.kinds(row[1], row[2])
				out[i] = { entries(kinds), entries(map.to_buffer(row[2], row[3], kinds)) }
			end
			return out]],
			{ rows }
		),
		vim.iter(rows)
			:map(function(row)
				return { entries(row[4]), entries(row[5]) }
			end)
			:totable()
	)
end

T["git: Committed signs map a large buffer quickly"] = MiniTest.new_set()

T["git: Committed signs map a large buffer quickly"]["maps ten thousand lines within the bound"] = function()
	local result = child.lua_get([[(function()
		local map = require("gleb.git.committed_signs.map")
		local base, head = {}, {}
		for i = 1, 10000 do
			base[i] = ("line %d"):format(i)
			head[i] = base[i]
		end
		head[5000] = "changed"
		local buffer = vim.deepcopy(head)
		table.insert(buffer, 1, "inserted")

		local started = vim.uv.hrtime()
		local kinds = map.kinds(base, head)
		local signs = map.to_buffer(head, buffer, kinds)
		return { elapsed = (vim.uv.hrtime() - started) / 1000000, sign = signs[5001] }
	end)()]])

	eq(result.sign, "change")
	eq(result.elapsed < 50 * H.load_factor(), true, { fail_reason = ("took %.2f ms"):format(result.elapsed) })
end

return T
