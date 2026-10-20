local MiniTest = require("mini.test")
local H = require("tests.helpers")
local budget = require("tests.smoke.budget")

local BASE_BUDGET_MS = 120
local STARTUP_RUNS = 3
local TIMEOUT_MS = 120000

---@param file string
---@return number
local function started_at(file)
	for _, line in ipairs(vim.fn.readfile(file)) do
		local ms = line:match("^(%d+%.%d+)%s+%d+%.%d+:%s+%-%-%- NVIM STARTED %-%-%-")
		if ms then
			return tonumber(ms) --[[@as number]]
		end
	end
	error("NVIM STARTED not found in " .. file)
end

---@return number
local function measure_startup()
	local file = vim.fn.tempname()
	local process = vim.system({ vim.v.progpath, "--headless", "--startuptime", file, "+qa!" }, {
		text = true,
		timeout = TIMEOUT_MS,
	})
	local result = process:wait()
	H.delete_debug_log(process.pid)
	assert(result.code == 0, result.stderr)
	assert(result.stderr == "", result.stderr)
	return started_at(file)
end

local T = MiniTest.new_set()

T["plugins: Warm real-config startup stays within budget"] = MiniTest.new_set()

T["plugins: Warm real-config startup stays within budget"]["uses the 120 ms base budget"] = function()
	H.isolate()
	measure_startup()
	local samples = {}
	for _ = 1, STARTUP_RUNS do
		table.insert(samples, measure_startup())
	end
	table.sort(samples)
	local median = samples[math.ceil(#samples / 2)]
	local allowed = budget.startup_budget(BASE_BUDGET_MS)
	assert(median <= allowed, string.format("startup %.1f ms exceeds load-normalized budget %d ms", median, allowed))
end

return T
