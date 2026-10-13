-- Per-session message log in /tmp/nvim/<ts>_<pid>.txt, started first from init.lua so it sees
-- every message after it. A repeating timer reopens the log so it is readable while the session runs.
local M = {}

local LOG_DIR = "/tmp/nvim"
local FLUSH_INTERVAL_MS = 2000
local AUGROUP = "gleb_nvim_debug_log"

---@class gleb.NvimDebugLogState
---@field path string? log file of this session, set by the first setup()
---@field timer integer? flush timer id while logging
---@type gleb.NvimDebugLogState
local state = {}

-- 'verbosefile' gets every message and, unlike :redir, leaves the single :redir slot to the
-- user and plugins. noautocmd keeps the 2000 ms toggle from firing OptionSet.
---@param path string
local function set_verbosefile(path)
	vim.cmd("noautocmd set verbosefile=" .. vim.fn.fnameescape(path))
end

---@return boolean
local function owns_verbosefile()
	return state.path ~= nil and vim.o.verbosefile == state.path
end

-- Closing and reopening the file writes its buffer; it reopens in append mode.
local function flush()
	if owns_verbosefile() then
		set_verbosefile("")
		set_verbosefile(state.path)
	end
end

local function register_exit()
	local group = vim.api.nvim_create_augroup(AUGROUP, { clear = true })
	vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = M.stop })
end

---Start logging; a second call while logging does nothing.
---@return nil
function M.setup()
	if state.timer then
		return
	end
	vim.fn.mkdir(LOG_DIR, "p")
	state.path = state.path or string.format("%s/%d_%d.txt", LOG_DIR, os.time(), vim.fn.getpid())
	set_verbosefile(state.path)
	state.timer = vim.fn.timer_start(FLUSH_INTERVAL_MS, flush, { ["repeat"] = -1 })
	register_exit()
end

---Stop the flush timer and end the log; setup() may start it again.
---@return nil
function M.stop()
	if not state.timer then
		return
	end
	vim.fn.timer_stop(state.timer)
	state.timer = nil
	pcall(vim.api.nvim_del_augroup_by_name, AUGROUP)
	if owns_verbosefile() then
		set_verbosefile("")
	end
end

return M
