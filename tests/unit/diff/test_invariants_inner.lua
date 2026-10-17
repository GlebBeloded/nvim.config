-- Invariants translated from IntelliJ ComparisonUtilAutoTest (Apache-2.0, © JetBrains s.r.o.).
-- Modified: fixed-seed UTF-8 property checks rewritten for the Lua diff engine; see lua/gleb/diff/engine/NOTICE.

local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
end

local T = H.child_set(child, start)

T["diff: Random texts keep IntelliJ's inner invariants"] = function()
	local failure = child.lua_get([[(function()
		local engine = require("gleb.diff.engine")
		if type(engine.compare_words) ~= "function" then
			return "compare_words is missing"
		end
		if type(engine.compare_chars) ~= "function" then
			return "compare_chars is missing"
		end

		local policies = { "default", "trim_whitespaces", "ignore_whitespaces", "ignore_whitespaces_chunks" }
		local highlights = { "by_word", "by_word_split", "by_char" }
		local alphabets = {
			{ "\n", "\n", "\t", " ", " ", ".", "<", "!", "i", "j", "k", "l" },
			{ "\n", "\n", "\t", " ", " ", ".", "<", "!", "😂", "🤫", "🔫", "🧒", "m", "n", "o", "p" },
		}
		local state = 20261017

		local function random(limit)
			state = (1664525 * state + 1013904223) % 4294967296
			return state % limit
		end

		local function random_text(alphabet)
			local chars = {}
			for _ = 1, random(301) do
				chars[#chars + 1] = alphabet[random(#alphabet) + 1]
			end
			return table.concat(chars)
		end

		local function normalize_gap(text, policy_name)
			if policy_name == "default" then
				return text
			end
			return text:gsub("[ \t\n]", "")
		end

		local function normalize_changed(text, policy_name)
			if policy_name == "default" or policy_name == "trim_whitespaces" then
				return text
			end
			return text:gsub("[ \t\n]", "")
		end

		local function boundaries(text)
			local result = {}
			for character_index = 0, vim.str_utfindex(text) do
				result[vim.str_byteindex(text, character_index)] = true
			end
			return result
		end

		local function validate(text1, text2, policy_name, fragments)
			local valid1 = boundaries(text1)
			local valid2 = boundaries(text2)
			local previous1 = 0
			local previous2 = 0
			for index, fragment in ipairs(fragments) do
				if fragment.start1 < previous1 or fragment.start2 < previous2 then
					return ("range %d overlaps"):format(index)
				end
				if fragment.start1 > fragment.end1 or fragment.end1 > #text1
					or fragment.start2 > fragment.end2 or fragment.end2 > #text2
				then
					return ("range %d is out of bounds"):format(index)
				end
				if not valid1[fragment.start1] or not valid1[fragment.end1]
					or not valid2[fragment.start2] or not valid2[fragment.end2]
				then
					return ("range %d splits UTF-8"):format(index)
				end
				local gap1 = text1:sub(previous1 + 1, fragment.start1)
				local gap2 = text2:sub(previous2 + 1, fragment.start2)
				if normalize_gap(gap1, policy_name) ~= normalize_gap(gap2, policy_name) then
					return ("gap before range %d differs"):format(index)
				end
				local changed1 = text1:sub(fragment.start1 + 1, fragment.end1)
				local changed2 = text2:sub(fragment.start2 + 1, fragment.end2)
				if normalize_changed(changed1, policy_name) == normalize_changed(changed2, policy_name) then
					return ("range %d is equal"):format(index)
				end
				previous1 = fragment.end1
				previous2 = fragment.end2
			end
			local suffix1 = text1:sub(previous1 + 1)
			local suffix2 = text2:sub(previous2 + 1)
			if normalize_gap(suffix1, policy_name) ~= normalize_gap(suffix2, policy_name) then
				return "suffix gap differs"
			end
		end

		local function split_lines(text)
			return vim.split(text, "\n", { plain = true })
		end

		local function fragment_text(lines, start_index, end_index)
			return table.concat(lines, "\n", start_index + 1, end_index)
		end

		local function comparison_text(lines, start_index, end_index)
			local text = fragment_text(lines, start_index, end_index)
			if start_index < end_index and end_index < #lines then
				return text .. "\n"
			end
			return text
		end

		local function line_gap_equal(lines1, start1, end1, lines2, start2, end2, policy_name)
			if policy_name == "ignore_whitespaces_chunks" then
				return normalize_gap(fragment_text(lines1, start1, end1), policy_name)
					== normalize_gap(fragment_text(lines2, start2, end2), policy_name)
			end
			if end1 - start1 ~= end2 - start2 then
				return false
			end
			for offset = 0, end1 - start1 - 1 do
				if normalize_gap(lines1[start1 + offset + 1], policy_name)
					~= normalize_gap(lines2[start2 + offset + 1], policy_name)
				then
					return false
				end
			end
			return true
		end

		local function validate_inner(lines1, lines2, policy_name, fragments)
			local previous1 = 0
			local previous2 = 0
			for index, fragment in ipairs(fragments) do
				if fragment.start1 < previous1 or fragment.start2 < previous2
					or fragment.start1 > fragment.end1 or fragment.end1 > #lines1
					or fragment.start2 > fragment.end2 or fragment.end2 > #lines2
				then
					return ("line range %d is invalid"):format(index)
				end
				if not line_gap_equal(lines1, previous1, fragment.start1, lines2, previous2, fragment.start2, policy_name) then
					return ("gap before line range %d differs"):format(index)
				end
				if fragment.inner ~= nil then
					local text1 = comparison_text(lines1, fragment.start1, fragment.end1)
					local text2 = comparison_text(lines2, fragment.start2, fragment.end2)
					local message = validate(text1, text2, policy_name, fragment.inner)
					if message then
						return ("line range %d inner %s"):format(index, message)
					end
				end
				previous1 = fragment.end1
				previous2 = fragment.end2
			end
			if not line_gap_equal(lines1, previous1, #lines1, lines2, previous2, #lines2, policy_name) then
				return "line suffix gap differs"
			end
		end

		for alphabet_index, alphabet in ipairs(alphabets) do
			for run = 1, 30 do
				local text1 = random_text(alphabet)
				local text2 = random_text(alphabet)
				local lines1 = split_lines(text1)
				local lines2 = split_lines(text2)
				for _, policy_name in ipairs(policies) do
					for _, comparison in ipairs({ "words", "chars" }) do
						local fragments = engine["compare_" .. comparison](text1, text2, { policy = policy_name })
						local message = validate(text1, text2, policy_name, fragments)
						if message then
							return ("alphabet %d run %d policy %s %s: %s")
								:format(alphabet_index, run, policy_name, comparison, message)
						end
					end
					for _, highlight in ipairs(highlights) do
						local result = engine.compare_lines(lines1, lines2, {
							policy = policy_name,
							highlight = highlight,
						})
						if result.too_big or result.timed_out then
							return ("alphabet %d run %d policy %s highlight %s: fallback")
								:format(alphabet_index, run, policy_name, highlight)
						end
						local message = validate_inner(lines1, lines2, policy_name, result.fragments)
						if message then
							return ("alphabet %d run %d policy %s highlight %s: %s")
								:format(alphabet_index, run, policy_name, highlight, message)
						end
					end
				end
			end
		end
		return vim.NIL
	end)()]])
	eq(failure, vim.NIL)
end

return T
