-- mini.test entry point used by the Makefile.
--   nvim --headless --noplugin -u tests/minimal_init.lua -c "lua require('tests.runner').run('unit')"
-- Layers are directories under tests/ ("unit,integration" runs several).
-- FILE=<path> narrows to one file (or a directory's test files), CAPS=<cap>[,<cap>] to tests/<layer>/<cap>/,
-- CASE=<substring> to matching case names. tests/parallel.lua shards a run:
-- TEST_SHARD_CASES lists the indices (among the matched cases) this process
-- runs, and the results are written as JSON to TEST_SHARD_OUT instead of the
-- stdout report.

local MiniTest = require("mini.test")

local M = {}

M.DEFAULT_LAYERS = { "unit", "integration", "screen" }

local SERIAL_FILES = {
	["tests/integration/lsp/test_readiness.lua"] = true,
}

---@param layer string? comma-separated layer directories, nil/"" for the default layers
---@return string[]
function M.find_files(layer)
	if vim.env.FILE and vim.env.FILE ~= "" then
		if vim.fn.isdirectory(vim.env.FILE) == 0 then
			return { vim.env.FILE }
		end
		local files = vim.fn.globpath(vim.env.FILE, "**/test_*.lua", false, true)
		table.sort(files)
		return files
	end
	local layers = (layer and layer ~= "") and vim.split(layer, ",", { trimempty = true }) or M.DEFAULT_LAYERS
	local caps = vim.split(vim.env.CAPS or "", ",", { trimempty = true })
	local subdirs = #caps > 0 and caps or { "" }
	local files = {}
	for _, dir in ipairs(layers) do
		for _, cap in ipairs(subdirs) do
			vim.list_extend(files, vim.fn.globpath(vim.fs.joinpath("tests", dir, cap), "**/test_*.lua", false, true))
		end
	end
	files = vim.tbl_filter(function(file)
		return not SERIAL_FILES[file]
	end, files)
	table.sort(files)
	return files
end

---@param case table mini.test case
---@return boolean
local function matches(case)
	local pattern = vim.env.CASE
	if not pattern or pattern == "" then
		return true
	end
	return table.concat(case.desc, " | "):find(pattern, 1, true) ~= nil
end

--- Cases matching FILE/CASE, optionally only the given indices among them.
---@param layer string?
---@param keep? table<integer, true>
---@return table[]
function M.collect(layer, keep)
	local index = 0
	return MiniTest.collect({
		find_files = function()
			return M.find_files(layer)
		end,
		filter_cases = function(case)
			if not matches(case) then
				return false
			end
			index = index + 1
			return keep == nil or keep[index] == true
		end,
	})
end

--- Reporter for a shard: no output, JSON results (with each case's duration)
--- written to `path` when done.
---@param path string
---@param indices integer[] global index of each collected case
---@return table
local function shard_reporter(path, indices)
	local cases, started, durations = {}, {}, {}
	local function results_so_far()
		local results = {}
		for i, case in ipairs(cases) do
			local exec = case.exec or { fails = {}, notes = {} }
			local ok_args, args = pcall(vim.json.encode, case.args or {})
			results[i] = {
				index = indices[i],
				desc = case.desc,
				args = ok_args and args or "[]",
				fails = exec.fails,
				notes = exec.notes,
				state = exec.state,
				ms = durations[i],
			}
		end
		return results
	end
	local function finish()
		vim.fn.writefile({ vim.json.encode(results_so_far()) }, path)
		vim.cmd("qa!")
	end
	return {
		start = function(all)
			cases = all
		end,
		update = function(i)
			started[i] = started[i] or vim.uv.hrtime()
			durations[i] = (vim.uv.hrtime() - started[i]) / 1e6
			-- progress for tests/parallel.lua: the case running now and the results so far, so a hung case
			-- is named when its worker is killed
			local partial = { current = indices[i], results = results_so_far() }
			vim.fn.writefile({ vim.json.encode(partial) }, path .. ".progress")
		end,
		finish = finish,
		finish_empty = finish,
	}
end

---@param layer string?
function M.run(layer)
	local out = vim.env.TEST_SHARD_OUT
	if out and out ~= "" then
		local indices = vim.tbl_map(tonumber, vim.split(vim.env.TEST_SHARD_CASES or "", ",", { trimempty = true }))
		table.sort(indices)
		local keep = {}
		for _, i in ipairs(indices) do
			keep[i] = true
		end
		local cases = M.collect(layer, keep)
		local reporter = shard_reporter(out, indices)
		if #cases == 0 then
			return reporter.finish_empty()
		end
		return MiniTest.execute(cases, { reporter = reporter })
	end

	local cases = M.collect(layer)
	if #cases == 0 then
		-- mini.test never calls the reporter's finish() for an empty run
		io.write("No test cases matched\n")
		vim.cmd("cquit 1")
	end
	MiniTest.execute(cases, { reporter = MiniTest.gen_reporter.stdout({ group_depth = 2 }) })
end

return M
