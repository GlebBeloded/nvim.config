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

return T
