local LOG_DIR = "/tmp/nvim"
local MAX_AGE_S = 7 * 24 * 60 * 60

--- Deletes `<time>_<pid>.txt` logs whose start time is older than `max_age_s`.
---@param dir string
---@param max_age_s integer
local function prune_old_logs(dir, max_age_s)
	for name, type in vim.fs.dir(dir) do
		local time = type == "file" and name:match("^(%d+)_%d+%.txt$")
		if time and os.time() - tonumber(time) > max_age_s then
			os.remove(vim.fs.joinpath(dir, name))
		end
	end
end

vim.fn.mkdir(LOG_DIR, "p")
prune_old_logs(LOG_DIR, MAX_AGE_S)

local path = string.format("%s/%d_%d.txt", LOG_DIR, os.time(), vim.fn.getpid())
local flush_interval_ms = 2000

vim.cmd("redir >> " .. path)

local function flush()
	vim.cmd("redir END")
	vim.cmd("redir >> " .. path)
end

local timer = vim.fn.timer_start(flush_interval_ms, function()
	flush()
end, { ["repeat"] = -1 })

vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = function()
		vim.fn.timer_stop(timer)
		vim.cmd("redir END")
	end,
})
