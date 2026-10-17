local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		function ComputeMoves(args)
			return require("gleb.diff.engine.moves").compute(args.changes, args.lines1, args.lines2, {
				clock = function() return 0 end,
				deadline = math.huge,
				myers_threshold = 20000,
			})
		end

		function CompareLines(lines1, lines2, opts)
			return require("gleb.diff.engine").compare_lines(lines1, lines2, opts)
		end

		function LineRanges(fragments)
			return vim.tbl_map(function(fragment)
				return { fragment.start1, fragment.end1, fragment.start2, fragment.end2 }
			end, fragments)
		end
	]])
end

local T = H.child_set(child, start)

T["diff: Short moves are ignored"] = function()
	local moved = { "x=10", "y=20", "z=30" }
	local stable = { "function a() end", "function b() end", "function c() end", "function d() end" }
	local lines1 = vim.list_extend(vim.deepcopy(moved), stable)
	local lines2 = vim.list_extend(vim.deepcopy(stable), moved)

	eq(
		child.lua_get(
			"ComputeMoves(...)",
			{ {
				changes = { { 0, 3, 0, 0 }, { 7, 7, 4, 7 } },
				lines1 = lines1,
				lines2 = lines2,
			} }
		),
		{}
	)
end

T["diff: Two-line moves are ignored"] = function()
	local moved = { "local limit = 2048", "local cheap = true" }
	local stable = { "function a() end", "function b() end", "function c() end", "function d() end" }
	local lines1 = vim.list_extend(vim.deepcopy(moved), stable)
	local lines2 = vim.list_extend(vim.deepcopy(stable), moved)

	eq(
		child.lua_get(
			"ComputeMoves(...)",
			{ {
				changes = { { 0, 2, 0, 0 }, { 6, 6, 4, 6 } },
				lines1 = lines1,
				lines2 = lines2,
			} }
		),
		{}
	)
end

local moved = { "local limit = 2048", "local cheap = true", "local count = 10" }
local stable = { "function a() end", "function b() end", "function c() end", "function d() end" }

local function moved_lines(moved_lines)
	return vim.list_extend(vim.deepcopy(stable), moved_lines or vim.deepcopy(moved))
end

T["diff: A moved block is detected"] = function()
	local result = child.lua_get("CompareLines(...)", {
		vim.list_extend(vim.deepcopy(moved), stable),
		moved_lines(),
		{ moves = true },
	})

	eq(child.lua_get("LineRanges(...)", { result.fragments }), { { 0, 3, 0, 0 }, { 7, 7, 4, 7 } })
	eq(result.moves, {
		{ start1 = 0, end1 = 3, start2 = 4, end2 = 7, fragments = {} },
	})
end

T["diff: A moved block with an edit carries its inner diff"] = function()
	local edited = { "local limit = 1024", "local cheap = true", "local count = 10" }
	local result = child.lua_get("CompareLines(...)", {
		vim.list_extend(vim.deepcopy(moved), stable),
		moved_lines(edited),
		{ moves = true },
	})

	eq(result.moves, {
		{
			start1 = 0,
			end1 = 3,
			start2 = 4,
			end2 = 7,
			fragments = {
				{
					start1 = 0,
					end1 = 1,
					start2 = 4,
					end2 = 5,
					inner = { { start1 = 14, end1 = 18, start2 = 14, end2 = 18 } },
				},
			},
		},
	})
end

T["diff: A block moved next to an edit is found by line windows"] = function()
	local lines1 = vim.list_extend(vim.deepcopy(moved), vim.deepcopy(stable))
	lines1[#lines1 + 1] = "return M"
	local lines2 = moved_lines()
	lines2[#lines2 + 1] = "return X"
	local result = child.lua_get("CompareLines(...)", { lines1, lines2, { moves = true } })

	eq(child.lua_get("LineRanges(...)", { result.fragments }), { { 0, 3, 0, 0 }, { 7, 8, 4, 8 } })
	eq(result.moves, {
		{ start1 = 0, end1 = 3, start2 = 4, end2 = 7, fragments = {} },
	})
end

T["diff: Moves are off by default"] = function()
	local result = child.lua_get("CompareLines(...)", {
		vim.list_extend(vim.deepcopy(moved), stable),
		moved_lines(),
	})

	eq(child.lua_get("LineRanges(...)", { result.fragments }), { { 0, 3, 0, 0 }, { 7, 7, 4, 7 } })
	eq(result.moves, {})
end

T["diff: A deadline during move detection drops moves"] = function()
	local result = child.lua_get(
		[[(function(lines1, lines2)
		local now = 0
		local moves = require("gleb.diff.engine.moves")
		local original = moves.compute
		moves.compute = function(...)
			now = 5000
			return original(...)
		end
		local comparison = CompareLines(lines1, lines2, {
			moves = true,
			limits = { timeout_ms = 1000, clock = function() return now end },
		})
		moves.compute = original
		return comparison
	end)(...)]],
		{
			vim.list_extend(vim.deepcopy(moved), stable),
			moved_lines(),
		}
	)

	eq(child.lua_get("LineRanges(...)", { result.fragments }), { { 0, 3, 0, 0 }, { 7, 7, 4, 7 } })
	eq(result.moves, {})
	eq(result.timed_out, true)
end

return T
