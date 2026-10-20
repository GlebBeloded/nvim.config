-- Parallel mini.test run: shard the matched cases across JOBS headless Neovim
-- workers (tests/runner.lua shard mode), then print one merged mini.test
-- report (fails and notes at the end) and exit non-zero on any failure.
--   nvim -u tests/minimal_init.lua -l tests/parallel.lua [layer[,layer]]
-- JOBS defaults to cores - 2. Cases are balanced by the durations of earlier
-- runs (.tests/timings.json); every worker isolates itself (tests/helpers.lua),
-- so workers share no temp paths. With ARTIFACTS_DIR set (a loop run), the
-- collected case names are added to $ARTIFACTS_DIR/case-seen.json, so the
-- gate sees a case added and removed again within one build pass.

local MiniTest = require("mini.test")
local runner = require("tests.runner")

local TIMINGS = ".tests/timings.json"
local CASE_SEEN = "case-seen.json" -- .archon/scripts/integrity.py reads it
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

---@class parallel.SeenCase
---@field file string
---@field case string

---@param path string
---@return parallel.SeenCase[]
local function read_seen(path)
	local ok, data = pcall(function()
		return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
	end)
	return ok and type(data) == "table" and data or {}
end

---@param entry parallel.SeenCase
---@return string
local function seen_key(entry)
	return entry.file .. "\0" .. entry.case
end

--- Add each collected case (file, last name key) to $ARTIFACTS_DIR/case-seen.json; no-op outside a loop run.
---@param cases table[]
local function record_seen(cases)
	local dir = vim.env.ARTIFACTS_DIR
	if not dir or dir == "" or vim.fn.isdirectory(dir) == 0 then
		return
	end
	local path = vim.fs.joinpath(dir, CASE_SEEN)
	local seen, keys = read_seen(path), {}
	for _, entry in ipairs(seen) do
		keys[seen_key(entry)] = true
	end
	for _, case in ipairs(cases) do
		local entry = { file = case.desc[1], case = case.desc[#case.desc] }
		if not keys[seen_key(entry)] then
			keys[seen_key(entry)] = true
			table.insert(seen, entry)
		end
	end
	local tmp = path .. "." .. vim.fn.getpid()
	vim.fn.writefile({ vim.json.encode(seen) }, tmp)
	vim.uv.fs_rename(tmp, path)
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
---@param on_exit fun(done: vim.SystemCompleted)
---@return vim.SystemObj
local function spawn(layer, indices, out, on_exit)
	local cmd = {
		vim.v.progpath,
		"--headless",
		"--noplugin",
		-- a worker whose run was killed exits too (24 workers outlived theirs by a day, Oct 2026)
		"--cmd",
		require("tests.helpers").WATCHDOG,
		"-u",
		"tests/minimal_init.lua",
		"-c",
		string.format("lua require('tests.runner').run(%q)", layer),
	}
	local env = { TEST_SHARD_CASES = table.concat(indices, ","), TEST_SHARD_OUT = out }
	return vim.system(cmd, { env = env, text = true }, on_exit)
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

-- a case with no progress this long is hung (e.g. a picker waiting for keys): its worker is killed and the
-- case fails by name, instead of `make check` running until the gate's timeout (run 8e207440)
local STALL_S = tonumber(vim.env.TEST_STALL_S) or 300

---@param path string
---@return { current: integer?, results: parallel.Result[] }?
local function read_progress(path)
	local ok, progress = pcall(function()
		return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
	end)
	return ok and progress or nil
end

--- Results of a worker killed on a stalled case: finished cases keep theirs, the stalled one fails as hung,
--- the rest of the shard fail as not run (the gate reruns them).
---@param worker table
---@param cases table[]
---@return parallel.Result[]
local function stalled(worker, cases)
	local progress = read_progress(worker.out .. ".progress") or { results = {} }
	local done = {}
	for _, r in ipairs(progress.results or {}) do
		if r.state and r.index ~= progress.current then
			done[r.index] = r
		end
	end
	return vim.tbl_map(function(i)
		if done[i] then
			return done[i]
		end
		local reason = i == progress.current
				and string.format("hung: no progress for %d s (waiting for input or a never-met condition?)", STALL_S)
			or "not run: its worker was killed after a hung case"
		return crashed({ i }, cases, reason)[1]
	end, worker.indices)
end

--- Waits for every worker, killing one whose progress file stays unchanged for STALL_S.
---@param workers table[]
local function wait_all(workers)
	local function mtime(worker)
		local stat = vim.uv.fs_stat(worker.out .. ".progress")
		return stat and stat.mtime.sec or worker.spawned
	end
	local function all_done()
		return vim.iter(workers):all(function(worker)
			return worker.result ~= nil
		end)
	end
	while not vim.wait(1000, all_done, 200) do
		for _, worker in ipairs(workers) do
			if not worker.result and not worker.stalled and os.time() - mtime(worker) > STALL_S then
				worker.stalled = true
				worker.process:kill(9)
			end
		end
	end
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
	record_seen(cases)
	local jobs = tonumber(vim.env.JOBS) or math.max(1, vim.uv.available_parallelism() - 2)
	jobs = math.min(jobs, #cases)
	local timings = read_timings()
	local shards = balance(cases, jobs, timings)

	local workers = {}
	for s, indices in ipairs(shards) do
		local out = vim.fn.tempname() .. ".json"
		local worker = { indices = indices, out = out, spawned = os.time() }
		worker.process = spawn(layer, indices, out, function(done)
			worker.result = done
		end)
		workers[s] = worker
	end
	wait_all(workers)

	local results, stderr = {}, {}
	for _, worker in ipairs(workers) do
		local done = worker.result
		local shard = worker.stalled and stalled(worker, cases) or read_results(worker.out)
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
