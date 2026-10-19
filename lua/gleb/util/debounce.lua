-- Shared one-shot debounce timers keep callbacks on Neovim's main loop; callers own delays and cleanup.

local M = {}

--- Schedule a callback after a quiet period, reusing the caller's timer when present.
---@param timer uv.uv_timer_t?
---@param delay_ms integer
---@param callback fun()
---@return uv.uv_timer_t
function M.schedule(timer, delay_ms, callback)
	timer = timer or assert(vim.uv.new_timer())
	timer:stop()
	timer:start(delay_ms, 0, vim.schedule_wrap(callback))
	return timer
end

return M
