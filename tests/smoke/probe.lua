-- Runs inside the real config (headless) for `make smoke`.
-- Emulates UI start, waits for VeryLazy, then writes a JSON report with the
-- message history and the ERROR/WARNING lines of the selected healthchecks.

---@class smoke.Report
---@field messages string
---@field errmsg string
---@field health string[] ERROR lines per healthcheck, prefixed with its name
---@field checks string[] healthchecks that ran

local out = assert(vim.env.SMOKE_OUT, "SMOKE_OUT not set")
local excluded = vim.split(vim.env.SMOKE_HEALTH_EXCLUDE or "", ",", { trimempty = true })

---@return string[]
local function health_checks()
	local names = vim.health._complete()
	return vim.tbl_filter(function(name)
		return not vim.list_contains(excluded, name)
	end, names)
end

---@param checks string[]
---@return string[]
local function health_errors(checks)
	vim.cmd("silent checkhealth " .. table.concat(checks, " "))
	local errors, section = {}, "?"
	for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
		section = line:match("^(%S+):.*require%(") or line:match("^(%S+):%s") or section
		if line:match("ERROR") then
			table.insert(errors, section .. " | " .. vim.trim(line))
		end
	end
	return errors
end

local function report()
	local messages = vim.fn.execute("messages")
	local checks = health_checks()
	---@type smoke.Report
	local result = { messages = messages, errmsg = vim.v.errmsg, checks = checks, health = health_errors(checks) }
	vim.fn.writefile({ vim.json.encode(result) }, out)
	vim.cmd("qa!")
end

local function on_very_lazy()
	-- let deferred startup work (vim.defer_fn, scheduled callbacks) settle
	vim.defer_fn(report, 1000)
end

vim.api.nvim_create_autocmd("User", { pattern = "VeryLazy", once = true, callback = on_very_lazy })
vim.api.nvim_exec_autocmds("UIEnter", {})
