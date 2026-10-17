local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		VscodeMoves = {}
		local fixture_dir = "tests/unit/diff/fixtures/vscode_moves"
		for name, kind in vim.fs.dir(fixture_dir) do
			if kind == "file" and vim.endswith(name, ".lua") then
				local fixture = dofile(fixture_dir .. "/" .. name)
				fixture.folder = name:sub(1, -5)
				table.insert(VscodeMoves, fixture)
			end
		end
		table.sort(VscodeMoves, function(a, b) return a.folder < b.folder end)

		function RunVscodeMoves()
			local ok, moves = pcall(require, "gleb.diff.engine.moves")
			if not ok then return "gleb.diff.engine.moves unavailable: " .. tostring(moves) end
			local context = {
				clock = function() return 0 end,
				deadline = math.huge,
				myers_threshold = 20000,
			}
			for _, fixture in ipairs(VscodeMoves) do
				local actual = moves.compute(fixture.changes, fixture.lines1, fixture.lines2, context)
				if not vim.deep_equal(actual, fixture.moves) then
					return fixture.folder .. ": " .. vim.inspect(actual)
				end
			end
			return true
		end
	]])
end

local T = H.child_set(child, start)

T["diff: Every VS Code move fixture passes"] = function()
	eq(child.lua_get("#VscodeMoves"), 58)
	eq(child.lua_get("RunVscodeMoves()"), true)
end

return T
