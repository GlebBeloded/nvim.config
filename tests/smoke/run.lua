-- `make smoke`: start the real config headless (isolated XDG dirs, see
-- tests/helpers.lua) and check that
--   1. startup leaves nothing in :messages / stderr,
--   2. the selected :checkhealth sections report no ERROR,
--   3. the median startup time (--startuptime) is within budget.
-- Run: nvim -u tests/minimal_init.lua -l tests/smoke/run.lua

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

local STARTUP_RUNS = 5
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
---@return vim.SystemCompleted
local function nvim(args, env)
	local cmd = vim.list_extend({ vim.v.progpath, "--headless" }, args)
	local process = vim.system(cmd, { text = true, env = env, timeout = TIMEOUT_MS })
	local result = process:wait()
	-- gleb.nvim_debug_log writes /tmp/nvim/<time>_<pid>.txt for every start
	for _, log in ipairs(vim.fn.glob("/tmp/nvim/*_" .. process.pid .. ".txt", false, true)) do
		vim.fn.delete(log)
	end
	return result
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

local function check_messages_and_health()
	H.isolate()
	local out = vim.fn.tempname()
	local probe = vim.fs.joinpath(H.root, "tests/smoke/probe.lua")
	local result = nvim({ "-c", "luafile " .. probe }, {
		SMOKE_OUT = out,
		SMOKE_HEALTH_EXCLUDE = table.concat(HEALTH_EXCLUDE, ","),
	})
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

local function check_startup_time()
	H.isolate()
	measure_startup() -- warm caches (vim.loader byte code, lazy state, helptags)
	local samples = {}
	for _ = 1, STARTUP_RUNS do
		table.insert(samples, measure_startup())
	end
	table.sort(samples)
	local median = samples[math.ceil(#samples / 2)]
	check(
		median <= STARTUP_BUDGET_MS,
		string.format("startup %.1f ms (median of %d) <= budget %d ms", median, STARTUP_RUNS, STARTUP_BUDGET_MS)
	)
end

check_messages_and_health()
check_startup_time()
io.write(failures == 0 and "smoke: ok\n" or string.format("smoke: %d failure(s)\n", failures))
io.flush()
os.exit(failures == 0 and 0 or 1)
