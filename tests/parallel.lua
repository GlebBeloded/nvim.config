-- Parallel mini.test run: shard the matched cases across JOBS headless Neovim
-- workers (tests/runner.lua shard mode), then print one merged mini.test
-- report (fails and notes at the end) and exit non-zero on any failure.
--   nvim -u tests/minimal_init.lua -l tests/parallel.lua [layer[,layer]]
-- JOBS defaults to cores - 2. Cases are balanced by the durations of earlier
-- runs (.tests/timings.json); every worker isolates itself (tests/helpers.lua),
-- so workers share no temp paths.

local MiniTest = require("mini.test")
local runner = require("tests.runner")

local TIMINGS = ".tests/timings.json"
local DEFAULT_MS = 500

---@class parallel.Result
---@field index integer
---@field desc string[]
---@field args string JSON
---@field fails string[]
---@field notes string[]
---@field state? string
---@field ms? number

---@param case { desc: string[] }
---@return string
local function case_id(case)
	return table.concat(case.desc, " | ")
end

---@return table<string, number>
local function read_timings()
	local ok, data = pcall(function()
		return vim.json.decode(table.concat(vim.fn.readfile(TIMINGS), "\n"))
	end)
	return ok and type(data) == "table" and data or {}
end

---@param timings table<string, number>
---@param results parallel.Result[]
local function write_timings(timings, results)
	for _, result in ipairs(results) do
		if result.ms then
			timings[case_id(result)] = math.floor(result.ms)
		end
	end
	vim.fn.mkdir(vim.fs.dirname(TIMINGS), "p")
	vim.fn.writefile({ vim.json.encode(timings) }, TIMINGS)
end

--- Longest-processing-time-first: each case goes to the least loaded shard.
---@param cases table[]
---@param jobs integer
---@param timings table<string, number>
---@return integer[][] case indices per shard
local function balance(cases, jobs, timings)
	local order = {}
	for i, case in ipairs(cases) do
		order[i] = { index = i, ms = timings[case_id(case)] or DEFAULT_MS }
	end
	table.sort(order, function(a, b)
		return a.ms > b.ms
	end)
	local shards, load = {}, {}
	for s = 1, jobs do
		shards[s], load[s] = {}, 0
	end
	for _, item in ipairs(order) do
		local lightest = 1
		for s = 2, jobs do
			if load[s] < load[lightest] then
				lightest = s
			end
		end
		table.insert(shards[lightest], item.index)
		load[lightest] = load[lightest] + item.ms
	end
	return shards
end

---@param layer string
---@param indices integer[]
---@param out string
---@return vim.SystemObj
local function spawn(layer, indices, out)
	local cmd = {
		vim.v.progpath,
		"--headless",
		"--noplugin",
		"-u",
		"tests/minimal_init.lua",
		"-c",
		string.format("lua require('tests.runner').run(%q)", layer),
	}
	local env = { TEST_SHARD_CASES = table.concat(indices, ","), TEST_SHARD_OUT = out }
	return vim.system(cmd, { env = env, text = true })
end

---@param indices integer[]
---@param cases table[]
---@param reason string
---@return parallel.Result[]
local function crashed(indices, cases, reason)
	return vim.tbl_map(function(i)
		return { index = i, desc = cases[i].desc, args = "[]", fails = { reason }, notes = {}, state = "Fail" }
	end, indices)
end

---@param path string
---@return parallel.Result[]?
local function read_results(path)
	local ok, results = pcall(function()
		return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
	end)
	return ok and results or nil
end

---@param results parallel.Result[]
---@return table[] cases in mini.test shape for its stdout reporter
local function to_cases(results)
	table.sort(results, function(a, b)
		return a.index < b.index
	end)
	return vim.tbl_map(function(r)
		local fails = type(r.fails) == "table" and r.fails or {}
		local notes = type(r.notes) == "table" and r.notes or {}
		return {
			desc = r.desc,
			args = vim.json.decode(r.args),
			exec = { fails = fails, notes = notes, state = r.state },
		}
	end, results)
end

---@param cases table[]
local function report(cases)
	local reporter = MiniTest.gen_reporter.stdout({ group_depth = 2, quit_on_finish = false })
	reporter.start(cases)
	for i = 1, #cases do
		reporter.update(i)
	end
	reporter.finish()
end

---@param cases table[]
---@return boolean
local function has_fails(cases)
	return vim.iter(cases):any(function(case)
		return #case.exec.fails > 0
	end)
end

local function main()
	local layer = _G.arg[1] or ""
	local started = vim.uv.hrtime()
	local cases = runner.collect(layer)
	if #cases == 0 then
		io.write("No test cases matched\n")
		return 1
	end
	local jobs = tonumber(vim.env.JOBS) or math.max(1, vim.uv.available_parallelism() - 2)
	jobs = math.min(jobs, #cases)
	local timings = read_timings()
	local shards = balance(cases, jobs, timings)

	local workers = {}
	for s, indices in ipairs(shards) do
		local out = vim.fn.tempname() .. ".json"
		workers[s] = { indices = indices, out = out, process = spawn(layer, indices, out) }
	end

	local results, stderr = {}, {}
	for _, worker in ipairs(workers) do
		local done = worker.process:wait()
		local shard = read_results(worker.out)
		if not shard then
			local reason = string.format("worker exited %d without results\n%s", done.code, done.stderr or "")
			shard = crashed(worker.indices, cases, reason)
		end
		vim.list_extend(results, shard)
		if vim.trim(done.stderr or "") ~= "" then
			table.insert(stderr, done.stderr)
		end
	end
	write_timings(timings, results)

	local merged = to_cases(results)
	report(merged)
	if #stderr > 0 then
		io.write("Worker stderr:\n" .. table.concat(stderr, "\n") .. "\n")
	end
	io.write(string.format("%d cases on %d workers in %.1f s\n", #merged, jobs, (vim.uv.hrtime() - started) / 1e9))
	return has_fails(merged) and 1 or 0
end

local status = main()
io.flush()
os.exit(status)
