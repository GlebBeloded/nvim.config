local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		function CompareLines(lines1, lines2, opts)
			return require("gleb.diff.engine").compare_lines(lines1, lines2, opts)
		end

		local function line_range(fragment)
			return { start1 = fragment.start1, end1 = fragment.end1, start2 = fragment.start2, end2 = fragment.end2 }
		end

		function LineRanges(fragments)
			return vim.tbl_map(line_range, fragments)
		end
	]])
end

local T = H.child_set(child, start)

T["diff: Changed lines become fragments"] = function()
	eq(child.lua_get([[CompareLines({ "x", "y", "z" }, { "n", "k", "y" }, { highlight = "by_line" })]]), {
		fragments = {
			{ start1 = 0, end1 = 1, start2 = 0, end2 = 2 },
			{ start1 = 2, end1 = 3, start2 = 3, end2 = 3 },
		},
		too_big = false,
		timed_out = false,
	})
end

T["diff: Identical lines have no fragments"] = function()
	eq(child.lua_get([[CompareLines({ "a", "b" }, { "a", "b" })]]), {
		fragments = {},
		too_big = false,
		timed_out = false,
	})
end

T["diff: Lines added after an empty line"] = function()
	eq(child.lua_get([[CompareLines({ "" }, { "", "", "" })]]), {
		fragments = {
			{ start1 = 1, end1 = 1, start2 = 1, end2 = 3 },
		},
		too_big = false,
		timed_out = false,
	})
end

T["diff: The engine loads without plugins"] = function()
	local result = child.lua_get([[
		(function()
			local before = {}
			for name in pairs(package.loaded) do before[name] = true end
			local compared = CompareLines({ "before" }, { "after" })
			local unexpected = {}
			for name in pairs(package.loaded) do
				if not before[name] and not vim.startswith(name, "gleb.diff.engine") then
					table.insert(unexpected, name)
				end
			end
			table.sort(unexpected)
			return { fragments = LineRanges(compared.fragments), unexpected = unexpected }
		end)()
	]])
	eq(result, {
		fragments = { { start1 = 0, end1 = 1, start2 = 0, end2 = 1 } },
		unexpected = {},
	})
end

T["diff: Brace lines do not anchor a match"] = function()
	eq(child.lua_get([[CompareLines({ "{", "}" }, { "{", " {", " }", "}", "x" }).fragments]]), {
		{ start1 = 1, end1 = 1, start2 = 1, end2 = 3 },
		{ start1 = 2, end1 = 2, start2 = 4, end2 = 5 },
	})
end

T["diff: Shifted indentation realigns exactly"] = function()
	eq(child.lua_get([[CompareLines({ ".{", "..{", "...{" }, { "..{", "...{" }).fragments]]), {
		{ start1 = 0, end1 = 1, start2 = 0, end2 = 0 },
	})
end

T["diff: An inserted function slides to the empty line"] = function()
	eq(
		child.lua_get([[
			CompareLines(
				{ "fun a() {", "    body", "}", "", "fun c() {", "    body", "}" },
				{
					"fun a() {", "    body", "}", "",
					"fun b() {", "    body", "}", "",
					"fun c() {", "    body", "}"
				}
			).fragments
		]]),
		{
			{ start1 = 4, end1 = 4, start2 = 4, end2 = 8 },
		}
	)
end

return T
