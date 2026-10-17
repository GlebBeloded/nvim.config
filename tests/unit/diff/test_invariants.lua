local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
end

local T = H.child_set(child, start)

T["diff: Random texts keep IntelliJ's line invariants"] = function()
	local failure = child.lua_get([[(function()
		local engine = require("gleb.diff.engine")
		local policies = { "default", "trim_whitespaces", "ignore_whitespaces", "ignore_whitespaces_chunks" }
		local alphabets = {
			{ "\n", "\n", "\t", " ", " ", ".", "<", "!", "i", "j", "k", "l" },
			{ "\n", "\n", "\t", " ", " ", ".", "<", "!", "😂", "🤫", "🔫", "🧒", "m", "n", "o", "p" },
		}
		local state = 20261017

		local function random(limit)
			state = (1664525 * state + 1013904223) % 4294967296
			return state % limit
		end

		local function random_lines(alphabet)
			local chars = {}
			for _ = 1, random(301) do
				chars[#chars + 1] = alphabet[random(#alphabet) + 1]
			end
			local text = table.concat(chars)
			local lines = {}
			local start_at = 1
			while true do
				local newline = text:find("\n", start_at, true)
				if not newline then
					lines[#lines + 1] = text:sub(start_at)
					return lines
				end
				lines[#lines + 1] = text:sub(start_at, newline - 1)
				start_at = newline + 1
			end
		end

		local function key(line, policy_name)
			if policy_name == "default" then
				return line
		end
			if policy_name == "trim_whitespaces" then
				return line:gsub("^[ \t\n]+", ""):gsub("[ \t\n]+$", "")
			end
			return line:gsub("[ \t\n]", "")
		end

		local function is_big(line)
			local compact = line:gsub("[ \t\n]", "")
			return vim.fn.strchars(compact) > 3
		end

		local function check(lines1, lines2, policy_name, fragments)
			local function check_gap(start1, end1, start2, end2)
				if policy_name == "ignore_whitespaces_chunks" then
					local gap1 = table.concat(vim.list_slice(lines1, start1 + 1, end1), "\n")
					local gap2 = table.concat(vim.list_slice(lines2, start2 + 1, end2), "\n")
					return key(gap1, policy_name) == key(gap2, policy_name)
				end
				if end1 - start1 ~= end2 - start2 then
					return false
				end
				for offset = 0, end1 - start1 - 1 do
					if key(lines1[start1 + offset + 1], policy_name) ~= key(lines2[start2 + offset + 1], policy_name) then
						return false
					end
				end
				return true
			end

			local previous1 = 0
			local previous2 = 0
			for fragment_index, fragment in ipairs(fragments) do
				if fragment.start1 < previous1 or fragment.start2 < previous2 then
					return ("fragment %d overlaps"):format(fragment_index)
				end
				if fragment.start1 > fragment.end1 or fragment.end1 > #lines1
					or fragment.start2 > fragment.end2 or fragment.end2 > #lines2
				then
					return ("fragment %d is out of range"):format(fragment_index)
				end
				if fragment.start1 == fragment.end1 and fragment.start2 == fragment.end2 then
					return ("fragment %d is empty"):format(fragment_index)
				end
				if not check_gap(previous1, fragment.start1, previous2, fragment.start2) then
					return ("gap before fragment %d differs"):format(fragment_index)
				end
				if policy_name == "ignore_whitespaces" and fragment.end1 > fragment.start1 and fragment.end2 > fragment.start2 then
					local first1 = lines1[fragment.start1 + 1]
					local first2 = lines2[fragment.start2 + 1]
					if is_big(first1) and is_big(first2) and key(first1, policy_name) == key(first2, policy_name) then
						return ("fragment %d can trim its first lines"):format(fragment_index)
					end
					local last1 = lines1[fragment.end1]
					local last2 = lines2[fragment.end2]
					if is_big(last1) and is_big(last2) and key(last1, policy_name) == key(last2, policy_name) then
						return ("fragment %d can trim its last lines"):format(fragment_index)
					end
				end
				previous1 = fragment.end1
				previous2 = fragment.end2
			end
			if not check_gap(previous1, #lines1, previous2, #lines2) then
				return "suffix gap differs"
			end
		end

		for alphabet_index, alphabet in ipairs(alphabets) do
			for run = 1, 30 do
				local lines1 = random_lines(alphabet)
				local lines2 = random_lines(alphabet)
				for _, policy_name in ipairs(policies) do
					local result = engine.compare_lines(lines1, lines2, { policy = policy_name })
					local message = check(lines1, lines2, policy_name, result.fragments)
					if message then
						return ("alphabet %d run %d policy %s: %s"):format(alphabet_index, run, policy_name, message)
					end
				end
			end
		end
		return vim.NIL
	end)()]])
	eq(failure, vim.NIL)
end

return T
