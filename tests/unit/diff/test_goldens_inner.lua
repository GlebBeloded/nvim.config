-- Translated IntelliJ fixtures (Apache-2.0, © JetBrains s.r.o.) are exercised here.
-- Modified: fixture checks rewritten for the Lua diff engine; see lua/gleb/diff/engine/NOTICE.

local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local FIXTURE_DIR = "tests/unit/diff/fixtures"
local child = H.new_child()

local function fixture(name)
	local path = FIXTURE_DIR .. "/" .. name .. ".lua"
	eq(vim.fn.filereadable(path), 1, { fail_reason = path .. " is missing" })
	return dofile(path)
end

local function start()
	child.start_bare()
	child.lua([[
		local engine = require("gleb.diff.engine")

		local function changed_bytes(fragments, side)
			local changed = {}
			for _, fragment in ipairs(fragments) do
				local start_offset = fragment["start" .. side]
				local end_offset = fragment["end" .. side]
				for offset = start_offset, end_offset - 1 do
					changed[#changed + 1] = offset
				end
			end
			return changed
		end

		local function tuple_fragments(fragments)
			local result = {}
			for _, fragment in ipairs(fragments) do
				result[#result + 1] = { fragment.start1, fragment.end1, fragment.start2, fragment.end2 }
			end
			return result
		end

		local function lines(text)
			return vim.split(text, "\n", { plain = true })
		end

		function CheckWordGoldens(rows)
			local failures = {}
			for _, row in ipairs(rows) do
				for policy, expected in pairs(row.expect) do
					local fragments = engine.compare_words(row.text1, row.text2, { policy = policy })
					local actual = {
						changed1 = changed_bytes(fragments, 1),
						changed2 = changed_bytes(fragments, 2),
					}
					if expected.fragments then actual.fragments = tuple_fragments(fragments) end
					if not vim.deep_equal(actual, expected) then
						failures[#failures + 1] = { source = row.source, policy = policy, expected = expected, actual = actual }
					end
					if row.kind == "lines_inner" then
						local result = engine.compare_lines(lines(row.text1), lines(row.text2), { policy = policy })
						local inner = #result.fragments == 1 and result.fragments[1].inner or {}
						local line_actual = {
							changed1 = changed_bytes(inner or {}, 1),
							changed2 = changed_bytes(inner or {}, 2),
						}
						if expected.fragments then line_actual.fragments = tuple_fragments(inner or {}) end
						if not vim.deep_equal(line_actual, expected) then
							failures[#failures + 1] = {
								source = row.source .. " lines",
								policy = policy,
								expected = expected,
								actual = line_actual,
							}
						end
					end
				end
			end
			return failures
		end

		function CheckCharGoldens(rows)
			local failures = {}
			for _, row in ipairs(rows) do
				for policy, expected in pairs(row.expect) do
					local fragments
					if row.kind == "chars_raw" then
						fragments = require("gleb.diff.engine.by_char").compare(row.text1, row.text2)
					elseif row.kind == "chars_smart" then
						fragments = require("gleb.diff.engine.by_char").compare_two_step(row.text1, row.text2)
					else
						fragments = engine.compare_chars(row.text1, row.text2, { policy = policy })
					end
					local actual = {
						changed1 = changed_bytes(fragments, 1),
						changed2 = changed_bytes(fragments, 2),
					}
					if expected.fragments then actual.fragments = tuple_fragments(fragments) end
					if not vim.deep_equal(actual, expected) then
						failures[#failures + 1] = { source = row.source, policy = policy, expected = expected, actual = actual }
					end
				end
			end
			return failures
		end

		function CheckSplitGoldens(rows)
			local failures = {}
			for _, row in ipairs(rows) do
				for policy, expected in pairs(row.expect) do
					local effective_policy = row.trim and policy == "ignore_whitespaces"
						and "ignore_whitespaces_chunks" or policy
					local result = engine.compare_lines(lines(row.text1), lines(row.text2), {
						policy = effective_policy,
						highlight = row.squash and "by_word" or "by_word_split",
					})
					local actual = { fragments = tuple_fragments(result.fragments) }
					if not vim.deep_equal(actual, expected) then
						failures[#failures + 1] = { source = row.source, policy = policy, expected = expected, actual = actual }
					end
				end
			end
			return failures
		end
	]])
end

local T = H.child_set(child, start)

T["diff: Every IntelliJ word case passes"] = function()
	local rows = fixture("intellij_words")
	eq(#rows, 78)
	eq(child.lua_get("CheckWordGoldens(...) ", { rows }), {})
end

T["diff: Every IntelliJ char case passes"] = function()
	local rows = fixture("intellij_chars")
	eq(#rows, 71)
	eq(child.lua_get("CheckCharGoldens(...) ", { rows }), {})
end

T["diff: Every IntelliJ split case passes"] = function()
	local rows = fixture("intellij_split")
	eq(#rows, 27)
	eq(child.lua_get("CheckSplitGoldens(...) ", { rows }), {})
end

T["diff: IntelliJ character classes hold"] = function()
	local trim = require("gleb.diff.engine.trim")
	local rows = fixture("intellij_chars_classes")
	local punctuation = {}
	for index = 1, #rows.punctuation do
		punctuation[string.byte(rows.punctuation, index)] = true
	end
	for codepoint = 0, 0xffff do
		eq(trim.is_punctuation(codepoint), punctuation[codepoint] == true)
	end
	for _, row in ipairs(rows.alpha) do
		for index = 0, vim.fn.strchars(row.text) - 1 do
			local codepoint = vim.fn.strgetchar(row.text, index)
			eq(trim.is_alpha(codepoint), row.expected, { fail_reason = row.text })
		end
	end
	for _, row in ipairs(rows.continuous) do
		for index = 0, vim.fn.strchars(row.text) - 1 do
			local codepoint = vim.fn.strgetchar(row.text, index)
			eq(trim.is_continuous_script(codepoint), row.expected, { fail_reason = row.text })
		end
	end
end

return T
