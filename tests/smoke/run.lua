-- `make smoke`: start the real config headless (isolated XDG dirs, see
-- tests/helpers.lua) and check that
--   1. startup leaves nothing in :messages / stderr,
--   2. the selected :checkhealth sections report no ERROR,
--   3. the median startup time (--startuptime) is within budget.
-- Run: nvim -u tests/minimal_init.lua -l tests/smoke/run.lua [health|startup]
-- Without an argument both parts run, the probe concurrently with the timing.

local H = require("tests.helpers")

--- Healthchecks skipped because they need external tools or report plugin
--- issues tracked in openspec/findings.md ("Smoke baseline").
local HEALTH_EXCLUDE = {
	"null-ls", -- external formatters/linters (markuplint, stylelint, shfmt, ...)
	"rustaceanvim", -- rust-analyzer binary
	"neotest-golang", -- testify queries need extra treesitter query files
	"neo-tree", -- config validation false positive (findings.md)
	"mason", -- package registry/network checks, external toolchains
	"vim.provider", -- python/node/ruby/perl providers are optional
}

--- ERROR lines that are known-benign (Lua patterns).
local HEALTH_IGNORE = {
	-- lazy reports "no plugins require luarocks, so you can ignore any warnings below"
	"lazy%-rocks/hererocks/bin/luarocks} not installed",
}

local STARTUP_RUNS = 3
local STARTUP_BUDGET_MS = tonumber(vim.env.STARTUP_BUDGET_MS) or 400
local TIMEOUT_MS = 120000

local failures = 0

---@param ok boolean
---@param label string
---@param detail? string
local function check(ok, label, detail)
	io.write(string.format("%s %s\n", ok and "ok  " or "FAIL", label))
	if not ok then
		failures = failures + 1
		if detail and detail ~= "" then
			io.write("     " .. detail:gsub("\n", "\n     ") .. "\n")
		end
	end
end

---@param args string[]
---@param env? table<string, string>
---@return fun(): vim.SystemCompleted wait for the started Neovim
local function spawn(args, env)
	local cmd = vim.list_extend({ vim.v.progpath, "--headless" }, args)
	local process = vim.system(cmd, { text = true, env = env, timeout = TIMEOUT_MS })
	return function()
		local result = process:wait()
		-- gleb.nvim_debug_log writes /tmp/nvim/<time>_<pid>.txt for every start
		H.delete_debug_log(process.pid)
		return result
	end
end

---@param args string[]
---@param env? table<string, string>
---@return vim.SystemCompleted
local function nvim(args, env)
	return spawn(args, env)()
end

---@param line string
---@return boolean
local function ignored(line)
	for _, pattern in ipairs(HEALTH_IGNORE) do
		if line:find(pattern) then
			return true
		end
	end
	return false
end

---@param result vim.SystemCompleted
---@param out string report path
local function check_report(result, out)
	check(result.code == 0, "probe exited cleanly", result.stderr)
	check(vim.trim(result.stderr or "") == "", "no stderr output", result.stderr)
	if vim.fn.filereadable(out) == 0 then
		return check(false, "probe wrote a report")
	end

	---@type smoke.Report
	local report = vim.json.decode(table.concat(vim.fn.readfile(out), "\n"))
	check(vim.trim(report.messages) == "", "no startup messages", report.messages)
	check(report.errmsg == "", "v:errmsg empty", report.errmsg)

	local errors = vim.tbl_filter(function(line)
		return not ignored(line)
	end, report.health)
	check(#errors == 0, "checkhealth without ERROR: " .. table.concat(report.checks, " "), table.concat(errors, "\n"))
end

--- Start the probe (own sandbox); the returned function checks its report.
---@return fun()
local function start_messages_and_health()
	H.isolate()
	local out = vim.fn.tempname()
	local probe = vim.fs.joinpath(H.root, "tests/smoke/probe.lua")
	local wait = spawn({ "-c", "luafile " .. probe }, {
		SMOKE_OUT = out,
		SMOKE_HEALTH_EXCLUDE = table.concat(HEALTH_EXCLUDE, ","),
	})
	return function()
		check_report(wait(), out)
	end
end

---@param file string --startuptime log
---@return number ms
local function started_at(file)
	for _, line in ipairs(vim.fn.readfile(file)) do
		local ms = line:match("^(%d+%.%d+)%s+%d+%.%d+:%s+%-%-%- NVIM STARTED %-%-%-")
		if ms then
			return tonumber(ms) --[[@as number]]
		end
	end
	error("NVIM STARTED not found in " .. file)
end

---@return number ms
local function measure_startup()
	-- the previous run saved a session on exit; a bare `nvim` would restore it
	vim.fn.delete(vim.fs.joinpath(vim.env.XDG_DATA_HOME, "nvim/session"), "rf")
	local file = vim.fn.tempname()
	nvim({ "--startuptime", file, "+qa!" })
	return started_at(file)
end

---@param runs integer
---@return number[] sorted samples
local function startup_samples(runs)
	local samples = {}
	for _ = 1, runs do
		table.insert(samples, measure_startup())
	end
	table.sort(samples)
	return samples
end

--- Median of STARTUP_RUNS starts (after warm_up). Over budget, it retries
--- once and judges the fastest of all samples instead: machine load only ever
--- adds time, so the minimum is the load-robust estimate.
local function check_startup_time()
	H.isolate()
	local samples = startup_samples(STARTUP_RUNS)
	local median = samples[math.ceil(#samples / 2)]
	if median <= STARTUP_BUDGET_MS then
		return check(
			true,
			string.format("startup %.1f ms (median of %d) <= budget %d ms", median, #samples, STARTUP_BUDGET_MS)
		)
	end
	vim.list_extend(samples, startup_samples(STARTUP_RUNS * 2))
	table.sort(samples)
	local load = vim.uv.loadavg()
	check(
		samples[1] <= STARTUP_BUDGET_MS,
		string.format(
			"startup %.1f ms (median %.1f over budget, retried: fastest of %d) <= budget %d ms, load %.1f",
			samples[1],
			median,
			#samples,
			STARTUP_BUDGET_MS,
			load
		)
	)
end

--- Fill the shared run cache (vim.loader byte code, lazy state, helptags)
--- before Neovims run concurrently: vim.loader writes its cache files in place,
--- so a concurrent reader can load a half-written module.
local function warm_up()
	H.isolate()
	measure_startup()
end

local part = _G.arg[1]
local timing = part == nil or part == "startup"
warm_up()
local finish_health = (part == nil or part == "health") and start_messages_and_health()
if timing then
	check_startup_time()
end
if finish_health then
	finish_health()
end
io.write(failures == 0 and "smoke: ok\n" or string.format("smoke: %d failure(s)\n", failures))
io.flush()
os.exit(failures == 0 and 0 or 1)
