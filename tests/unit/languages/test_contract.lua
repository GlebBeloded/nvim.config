local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, function()
	child.start_config()
end)

---@param setup string?
---@return string[]
local function contract_problems(setup)
	return child.lua_get(
		[[(function(...)
			local setup = ...
			local loaded, contract = pcall(require, "gleb.languages.contract")
			if not loaded then return { "contract module is missing" } end
			local registry = require("gleb.languages")
			local language = vim.deepcopy(registry.for_filetype("go"))
			if setup == "missing query" then
				language.name = "missing"
				language.filetypes = { "no_such_parser" }
				language.treesitter.parsers = { "no_such_parser" }
			elseif setup == "missing fixture" then
				language.references.fixture.project = "no-such-fixture"
			elseif setup == "stale queue" then
				language.references = { disabled = "queued: no-such-change" }
			end
			return contract.check(language)
		end)(...)]],
		{ setup }
	)
end

local configured_scenario = "languages: Every configured language meets the contract"
T[configured_scenario] = MiniTest.new_set()

T[configured_scenario]["contract"] = function()
	local problems = child.lua_get([[(function()
		local loaded, contract = pcall(require, "gleb.languages.contract")
		if not loaded then return { "contract module is missing" } end
		local problems = {}
		for _, language in ipairs(require("gleb.languages").all()) do
			vim.list_extend(problems, contract.check(language))
		end
		return problems
	end)()]])

	eq(problems, {})
end

T[configured_scenario]["query case tables"] = function()
	local names = child.lua_get([[(function()
		local names = {}
		for _, entry in ipairs(require("gleb.languages").facet("references")) do
			if entry.config.usage_types == true then table.insert(names, entry.language.name) end
		end
		return names
	end)()]])
	for _, name in ipairs({ "lua", "shell", "terraform" }) do
		eq(vim.tbl_contains(names, name), true)
	end
	for _, name in ipairs(names) do
		local query_cases = require("tests.unit.references.usage_cases." .. name)
		for _, suite in ipairs(query_cases.suites or { query_cases }) do
			local positions = vim.tbl_map(function(case)
				return { line = case.line, character = case.character }
			end, suite.cases)
			local expected = vim.tbl_map(function(case)
				return case.query_expected or case.expected
			end, suite.cases)
			local actual = child.lua_get(
				[[require("gleb.references.kind_ts").classify(...)]],
				{ suite.source, suite.filetype, positions }
			)
			eq(actual, expected)
		end
	end
end

T["references: Lua query classifies every usage type"] = function()
	local query_cases = require("tests.unit.references.usage_cases.lua")
	for _, suite in ipairs(query_cases.suites) do
		local positions = vim.tbl_map(function(case)
			return { line = case.line, character = case.character }
		end, suite.cases)
		local expected = vim.tbl_map(function(case)
			return case.expected
		end, suite.cases)
		local actual = child.lua_get(
			[[require("gleb.references.kind_ts").classify(...)]],
			{ suite.source, suite.filetype, positions }
		)
		eq(actual, expected)
	end
end

T["references: Bash query classifies every usage type"] = function()
	local query_cases = require("tests.unit.references.usage_cases.shell")
	for _, suite in ipairs(query_cases.suites) do
		local positions = vim.tbl_map(function(case)
			return { line = case.line, character = case.character }
		end, suite.cases)
		local expected = vim.tbl_map(function(case)
			return case.expected
		end, suite.cases)
		local actual = child.lua_get(
			[[require("gleb.references.kind_ts").classify(...)]],
			{ suite.source, suite.filetype, positions }
		)
		eq(actual, expected)
	end
end

T["references: Terraform query classifies every usage type"] = function()
	local query_cases = require("tests.unit.references.usage_cases.terraform")
	for _, suite in ipairs(query_cases.suites) do
		local positions = vim.tbl_map(function(case)
			return { line = case.line, character = case.character }
		end, suite.cases)
		local expected = vim.tbl_map(function(case)
			return case.expected
		end, suite.cases)
		local actual = child.lua_get(
			[[require("gleb.references.kind_ts").classify(...)]],
			{ suite.source, suite.filetype, positions }
		)
		eq(actual, expected)
	end
end

T["references: TypeScript query classifies every usage type"] = function()
	local query_cases = require("tests.unit.references.usage_cases.js")
	for _, suite in ipairs(query_cases.suites) do
		local positions = vim.tbl_map(function(case)
			return { line = case.line, character = case.character }
		end, suite.cases)
		local targets = vim.tbl_map(function(case)
			return case.kind or "unknown"
		end, suite.cases)
		local expected = vim.tbl_map(function(case)
			if case.query_expected == "read" then
				return "read"
			end
			return case.refined_expected
		end, suite.cases)
		local actual = child.lua_get(
			[[(function(source, filetype, source_positions, target_kinds)
				local classify = require("gleb.references.kind_ts").classify
				local refine = require("gleb.references.kind_refine").refine_query_kind
				local refined = {}
				for index, query_kind in ipairs(classify(source, filetype, source_positions)) do
					refined[index] = refine(query_kind, target_kinds[index], filetype) or false
				end
				return refined
			end)(...)]],
			{ suite.source, suite.filetype, positions, targets }
		)
		eq(actual, expected)
	end
end

T["references: Python query classifies every usage type"] = function()
	local suite = require("tests.unit.references.usage_cases.python")
	local positions = vim.tbl_map(function(case)
		return { line = case.line, character = case.character }
	end, suite.cases)
	local expected = vim.tbl_map(function(case)
		if case.kind then
			return case.refined_expected
		end
		return case.query_expected
	end, suite.cases)
	local targets = vim.tbl_map(function(case)
		return case.kind or false
	end, suite.cases)
	local actual = child.lua_get(
		[[(function(source, filetype, source_positions, target_kinds)
			local classify = require("gleb.references.kind_ts").classify
			local refine = require("gleb.references.kind_refine").refine_query_kind
			local refined = {}
			for index, query_kind in ipairs(classify(source, filetype, source_positions)) do
				local target = target_kinds[index]
				local drops_read_write = target and (target == "function" or target == "type")
					and (query_kind == "write" or query_kind == "read")
				if not target then
					refined[index] = query_kind
				elseif drops_read_write then
					refined[index] = false
				else
					refined[index] = refine(query_kind, target, filetype) or false
				end
			end
			return refined
		end)(...)]],
		{ suite.source, suite.filetype, positions, targets }
	)
	eq(actual, expected)
end

T["references: Rust query classifies every usage type"] = function()
	local suite = require("tests.unit.references.usage_cases.rust")
	local positions = vim.tbl_map(function(case)
		return { line = case.line, character = case.character }
	end, suite.cases)
	local expected = vim.tbl_map(function(case)
		return case.kind and case.refined_expected or case.query_expected
	end, suite.cases)
	local targets = vim.tbl_map(function(case)
		return case.kind or false
	end, suite.cases)
	local actual = child.lua_get(
		[[(function(source, filetype, source_positions, target_kinds)
			local classify = require("gleb.references.kind_ts").classify
			local refine = require("gleb.references.kind_refine").refine_query_kind
			local refined = {}
			for index, query_kind in ipairs(classify(source, filetype, source_positions)) do
				local target_kind = target_kinds[index]
				refined[index] = target_kind and refine(query_kind, target_kind, filetype) or query_kind
			end
			return refined
		end)(...)]],
		{ suite.source, suite.filetype, positions, targets }
	)
	eq(actual, expected)
end

T["languages: A missing usages query breaks the contract"] = function()
	local problems = contract_problems("missing query")

	eq(vim.tbl_contains(problems, "missing: references.usage_types needs queries/no_such_parser/usages.scm"), true)
end

T["languages: A missing fixture breaks the contract"] = function()
	local problems = contract_problems("missing fixture")

	eq(
		vim.tbl_contains(problems, "go: references.fixture.project no-such-fixture is not in tests/fixtures/build.sh"),
		true
	)
end

T["languages: A stale queued reason breaks the contract"] = function()
	local problems = contract_problems("stale queue")

	eq(vim.tbl_contains(problems, "go: queued change no-such-change does not exist"), true)
end

T[configured_scenario]["Each references facet gets a gr run"] = function()
	local scenario = "languages: Each references facet gets a gr run"
	local cases = MiniTest.collect({
		find_files = function()
			return { "tests/integration/references/test_languages.lua" }
		end,
	})
	local actual = {}
	for _, case in ipairs(cases) do
		if vim.tbl_contains(case.desc, scenario) then
			table.insert(actual, case.desc[#case.desc])
		end
	end
	table.sort(actual)

	local expected = vim.tbl_map(function(entry)
		return entry.language.name
	end, require("gleb.languages").facet("references"))
	table.sort(expected)
	eq(actual, expected)
end

return T
