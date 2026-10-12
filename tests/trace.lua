-- `make trace`: traceability matrix between OpenSpec scenarios and mini.test
-- cases. A case is linked to a scenario when its name is exactly
-- "<capability>: <scenario title>" (capability = openspec/specs/<capability>).
--   tested  - scenario has at least one case
--   missing - scenario has no case (reported, not fatal yet)
--   orphan  - case name matches no scenario (fatal)
-- Run: nvim -u tests/minimal_init.lua -l tests/trace.lua [--quiet]

local MiniTest = require("mini.test")

local SPECS_DIR = "openspec/specs"
local TEST_LAYERS = { "unit", "integration", "screen" }
local quiet = vim.list_contains(_G.arg or {}, "--quiet")

---@class trace.Scenario
---@field capability string
---@field title string
---@field cases string[] files of linked cases

---@param path string
---@return string[]
local function scenario_titles(path)
	local titles = {}
	for _, line in ipairs(vim.fn.readfile(path)) do
		local title = line:match("^#### Scenario:%s*(.-)%s*$")
		if title then
			table.insert(titles, title)
		end
	end
	return titles
end

---@return table<string, table<string, trace.Scenario>> by capability, then title
---@return string[] capabilities sorted
local function load_specs()
	local specs, capabilities = {}, {}
	for _, path in ipairs(vim.fn.glob(SPECS_DIR .. "/*/spec.md", false, true)) do
		local capability = vim.fs.basename(vim.fs.dirname(path))
		specs[capability] = {}
		table.insert(capabilities, capability)
		for _, title in ipairs(scenario_titles(path)) do
			specs[capability][title] = { capability = capability, title = title, cases = {} }
		end
	end
	table.sort(capabilities)
	return specs, capabilities
end

---@return string[]
local function test_files()
	local files = {}
	for _, layer in ipairs(TEST_LAYERS) do
		vim.list_extend(files, vim.fn.globpath("tests/" .. layer, "**/test_*.lua", false, true))
	end
	table.sort(files)
	return files
end

---@return { name: string, file: string }[]
local function collect_cases()
	local cases = MiniTest.collect({ find_files = test_files })
	return vim.tbl_map(function(case)
		return { name = case.desc[#case.desc], file = case.desc[1] }
	end, cases)
end

---@param specs table<string, table<string, trace.Scenario>>
---@param cases { name: string, file: string }[]
---@return string[] orphans
local function link(specs, cases)
	local orphans = {}
	for _, case in ipairs(cases) do
		local capability, title = case.name:match("^([%w%-]+): (.+)$")
		local scenario = capability and specs[capability] and specs[capability][title]
		if scenario then
			table.insert(scenario.cases, case.file)
		else
			table.insert(orphans, string.format("%s  (%s)", case.name, case.file))
		end
	end
	return orphans
end

---@param fmt string
local function out(fmt, ...)
	io.write(string.format(fmt, ...) .. "\n")
end

---@param scenarios table<string, trace.Scenario>
---@return string[]
local function sorted_titles(scenarios)
	local titles = vim.tbl_keys(scenarios)
	table.sort(titles)
	return titles
end

---@param scenario trace.Scenario
---@return string
local function scenario_row(scenario)
	if #scenario.cases == 0 then
		return "  MISSING  " .. scenario.title
	end
	local layers = vim.tbl_map(function(file)
		return file:match("^tests/(%w+)/") or file
	end, scenario.cases)
	table.sort(layers)
	local unique = vim.fn.uniq(layers) --[[@as string[] ]]
	return string.format("  tested   %s  [%s]", scenario.title, table.concat(unique, ","))
end

---@param scenarios table<string, trace.Scenario>
---@return integer tested, integer total
local function count(scenarios)
	local tested, total = 0, 0
	for _, scenario in pairs(scenarios) do
		total = total + 1
		tested = tested + (#scenario.cases > 0 and 1 or 0)
	end
	return tested, total
end

local specs, capabilities = load_specs()
local orphans = link(specs, collect_cases())
local all_tested, all_total = 0, 0

for _, capability in ipairs(capabilities) do
	local tested, total = count(specs[capability])
	all_tested, all_total = all_tested + tested, all_total + total
	out("%s  %d/%d", capability, tested, total)
	if not quiet then
		for _, title in ipairs(sorted_titles(specs[capability])) do
			out("%s", scenario_row(specs[capability][title]))
		end
	end
end

if #orphans > 0 then
	out('\nORPHAN cases (name is not "<capability>: <scenario title>"):')
	for _, orphan in ipairs(orphans) do
		out("  %s", orphan)
	end
end

out("\ntrace: %d scenarios, %d tested, %d missing, %d orphan", all_total, all_tested, all_total - all_tested, #orphans)
io.flush()
os.exit(#orphans > 0 and 1 or 0)
