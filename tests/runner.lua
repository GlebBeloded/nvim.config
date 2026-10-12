-- mini.test entry point used by the Makefile.
--   nvim --headless --noplugin -u tests/minimal_init.lua -c "lua require('tests.runner').run('unit')"
-- Layers are directories under tests/: unit, integration, screen. FILE=<path>
-- narrows to one file; CASE=<substring> narrows to matching case names.

local MiniTest = require("mini.test")

local M = {}

---@param layer string? layer directory, nil/"" for all layers
---@return string[]
local function find_files(layer)
	if vim.env.FILE and vim.env.FILE ~= "" then
		return { vim.env.FILE }
	end
	local layers = (layer and layer ~= "") and { layer } or { "unit", "integration", "screen" }
	local files = {}
	for _, dir in ipairs(layers) do
		vim.list_extend(files, vim.fn.globpath("tests/" .. dir, "**/test_*.lua", false, true))
	end
	table.sort(files)
	return files
end

---@param case table mini.test case
---@return boolean
local function case_filter(case)
	local pattern = vim.env.CASE
	if not pattern or pattern == "" then
		return true
	end
	return table.concat(case.desc, " | "):find(pattern, 1, true) ~= nil
end

---@param layer string?
function M.run(layer)
	local cases = MiniTest.collect({
		find_files = function()
			return find_files(layer)
		end,
		filter_cases = case_filter,
	})
	if #cases == 0 then
		-- mini.test never calls the reporter's finish() for an empty run
		io.write("No test cases matched\n")
		vim.cmd("cquit 1")
	end
	MiniTest.execute(cases, { reporter = MiniTest.gen_reporter.stdout({ group_depth = 2 }) })
end

return M
