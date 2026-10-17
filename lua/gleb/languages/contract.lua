-- Language contract checks keep repository-backed validation out of feature setup.
local M = {}

local languages = require("gleb.languages")
local usage_types = require("gleb.references.usage_types")

---@param problems string[]
---@param problem string
local function add(problems, problem)
	if not vim.tbl_contains(problems, problem) then
		table.insert(problems, problem)
	end
end

---@param language gleb.Language
---@param problems string[]
local function check_facets(language, problems)
	for name, validate in pairs(languages.state.facets) do
		local config = language[name]
		if type(config) == "table" and config.disabled == nil then
			local problem = validate(config, language)
			if problem then
				add(problems, problem)
			end
		end
	end
end

---@param language_name string
---@param value unknown
---@param problems string[]
local function check_queued_reasons(language_name, value, problems)
	if type(value) ~= "table" then
		return
	end
	local change = type(value.disabled) == "string" and value.disabled:match("^queued:%s*(%S+)%s*$") or nil
	if change then
		local config = vim.api.nvim_get_runtime_file("init.lua", false)[1]
		local root = config and vim.fs.dirname(config) or vim.fn.stdpath("config")
		local path = vim.fs.joinpath(root, "openspec", "changes", change)
		if vim.uv.fs_stat(path) == nil then
			add(problems, ("%s: queued change %s does not exist"):format(language_name, change))
		end
	end
	for _, nested in pairs(value) do
		if type(nested) == "table" then
			check_queued_reasons(language_name, nested, problems)
		end
	end
end

---@param language gleb.Language
---@param filetype string
---@return string
local function parser_language(language, filetype)
	local parser = vim.treesitter.language.get_lang(filetype) or filetype
	if vim.tbl_contains(language.treesitter.parsers, parser) then
		return parser
	end
	local ok, loaded = pcall(vim.treesitter.language.add, parser)
	if ok and loaded then
		return parser
	end
	if vim.tbl_contains(language.treesitter.parsers, language.name) then
		return language.name
	end
	if #language.treesitter.parsers == 1 then
		return language.treesitter.parsers[1]
	end
	return parser
end

---@param language gleb.Language
---@param parser string
---@param problems string[]
local function check_query(language, parser, problems)
	local prefix = language.name .. ": references.usage_types"
	local query_path = ("queries/%s/usages.scm"):format(parser)
	if #vim.api.nvim_get_runtime_file(query_path, false) == 0 then
		add(problems, ("%s needs %s"):format(prefix, query_path))
		return
	end
	local parser_ok, loaded = pcall(vim.treesitter.language.add, parser)
	if not parser_ok or not loaded then
		add(problems, ("%s parser %s is not installed"):format(language.name, parser))
		return
	end
	local query_ok, query = pcall(vim.treesitter.query.get, parser, "usages")
	if not query_ok or not query then
		add(problems, ("%s has an invalid %s"):format(language.name, query_path))
		return
	end
	for _, capture in ipairs(query.captures) do
		if not vim.startswith(capture, "_") then
			local id = capture:match("^usage%.(.+)$")
			if id == nil or usage_types[id] == nil then
				add(problems, ("%s: %s has unknown capture %s"):format(language.name, query_path, capture))
			end
		end
	end
end

---@param suite table
---@return boolean
local function valid_case_suite(suite)
	local valid = type(suite.filetype) == "string"
		and type(suite.source) == "string"
		and vim.islist(suite.cases)
		and #suite.cases > 0
	if valid then
		for _, case in ipairs(suite.cases) do
			valid = valid
				and type(case.line) == "number"
				and type(case.character) == "number"
				and type(case.expected) == "string"
		end
	end
	return valid
end

---@param cases table
---@return boolean
local function valid_case_table(cases)
	local suites = cases.suites or { cases }
	if not vim.islist(suites) or #suites == 0 then
		return false
	end
	for _, suite in ipairs(suites) do
		if type(suite) ~= "table" or not valid_case_suite(suite) then
			return false
		end
	end
	return true
end

---@param language gleb.Language
---@param problems string[]
local function check_cases(language, problems)
	local case_path = ("tests/unit/references/usage_cases/%s.lua"):format(language.name)
	local path = vim.api.nvim_get_runtime_file(case_path, false)[1]
	if not path then
		add(problems, ("%s: references.usage_types needs %s"):format(language.name, case_path))
		return
	end
	local loaded, cases = pcall(dofile, path)
	if not loaded or type(cases) ~= "table" or not valid_case_table(cases) then
		add(problems, ("%s: references.usage_types has invalid cases in %s"):format(language.name, case_path))
	end
end

---@param language gleb.Language
---@param problems string[]
local function check_fixture(language, problems)
	local references = language.references
	local project = references.fixture.project
	local symbol = references.fixture.symbol
	local config = vim.api.nvim_get_runtime_file("init.lua", false)[1]
	local root = config and vim.fs.dirname(config) or vim.fn.stdpath("config")
	local script = vim.fs.joinpath(root, "tests", "fixtures", "build.sh")
	local result = vim.system({ script, project }, { text = true }):wait(300000)
	if result.code ~= 0 then
		add(
			problems,
			("%s: references.fixture.project %s is not in tests/fixtures/build.sh"):format(language.name, project)
		)
		return
	end
	local manifest_path = vim.fs.joinpath(vim.trim(result.stdout), "manifest.json")
	local manifest_ok, manifest = pcall(function()
		return vim.json.decode(table.concat(vim.fn.readfile(manifest_path), "\n"))
	end)
	if not manifest_ok or type(manifest.references) ~= "table" or manifest.references[symbol] == nil then
		add(problems, ("%s: references.fixture.symbol %s is not in %s manifest"):format(language.name, symbol, project))
	end
end

---@param language gleb.Language
---@return string[]
function M.check(language)
	local problems = {}
	check_facets(language, problems)
	check_queued_reasons(language.name, language, problems)
	local references = language.references
	if type(references) ~= "table" or references.disabled ~= nil then
		return problems
	end
	check_fixture(language, problems)
	if references.usage_types == true then
		local seen = {}
		for _, filetype in ipairs(language.filetypes) do
			local parser = parser_language(language, filetype)
			if not vim.tbl_contains(language.treesitter.parsers, parser) then
				add(problems, ("%s: parser %s is not in the treesitter facet"):format(language.name, parser))
			elseif not seen[parser] then
				seen[parser] = true
				check_query(language, parser, problems)
			end
		end
		check_cases(language, problems)
	end
	return problems
end

return M
