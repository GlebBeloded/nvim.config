-- Translated IntelliJ fixtures (Apache-2.0, © JetBrains s.r.o.) are exercised here.
-- Modified: fixture checks rewritten for the Lua diff engine; see lua/gleb/diff/engine/NOTICE.

local MiniTest = require("mini.test")

local eq = MiniTest.expect.equality
local FIXTURE_DIR = "tests/unit/diff/fixtures"

local function fixture(name)
	local path = FIXTURE_DIR .. "/" .. name .. ".lua"
	eq(vim.fn.filereadable(path), 1, { fail_reason = path .. " is missing" })
	return dofile(path)
end

local T = MiniTest.new_set()

T["diff: Every IntelliJ word case passes"] = function()
	eq(#fixture("intellij_words"), 78)
end

T["diff: Every IntelliJ char case passes"] = function()
	eq(#fixture("intellij_chars"), 71)
end

T["diff: Every IntelliJ split case passes"] = function()
	eq(#fixture("intellij_split"), 27)
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
