-- Shared one-shot debounce timers keep callbacks on Neovim's main loop; callers own delays and cleanup.

local M = {}

---@class DebounceTestTimer: uv.uv_timer_t
---@field _debounce_test_timer true
---@field due_ms? integer
---@field callback? fun()
---@field closed boolean
local TestTimer = {}
TestTimer.__index = TestTimer

function TestTimer:stop()
	self.due_ms = nil
	self.callback = nil
end

function TestTimer:close()
	self:stop()
	self.closed = true
end

---@param delay_ms integer
---@param _ integer
---@param callback fun()
function TestTimer:start(delay_ms, _, callback)
	assert(not self.closed, "cannot start a closed debounce timer")
	self.due_ms = assert(M.state.scheduler).now_ms + delay_ms
	self.callback = callback
end

---@class DebounceTestScheduler
---@field now_ms integer
---@field timers DebounceTestTimer[]

---@class DebounceState
---@field scheduler? DebounceTestScheduler

---@type DebounceState
M.state = {}

---@return DebounceTestTimer
local function new_test_timer()
	local timer = setmetatable({
		_debounce_test_timer = true,
		closed = false,
	}, TestTimer)
	table.insert(assert(M.state.scheduler).timers, timer)
	return timer
end

---@param timer uv.uv_timer_t?
---@return boolean
local function is_test_timer(timer)
	return type(timer) == "table" and rawget(timer, "_debounce_test_timer") == true
end

--- Replace real debounce timers with a manually advanced scheduler for tests.
---@return nil
function M.use_test_scheduler()
	M.reset()
	M.state.scheduler = { now_ms = 0, timers = {} }
end

--- Advance the active test scheduler and run every callback due in the interval.
---@param delay_ms integer
---@return nil
function M.advance(delay_ms)
	local scheduler = assert(M.state.scheduler, "test debounce scheduler is not active")
	local target_ms = scheduler.now_ms + delay_ms
	while true do
		local next_timer
		for _, timer in ipairs(scheduler.timers) do
			if timer.due_ms and timer.due_ms <= target_ms and (not next_timer or timer.due_ms < next_timer.due_ms) then
				next_timer = timer
			end
		end
		if not next_timer then
			break
		end
		scheduler.now_ms = assert(next_timer.due_ms, "due debounce timer has no deadline")
		local callback = assert(next_timer.callback, "due debounce timer has no callback")
		next_timer.due_ms = nil
		next_timer.callback = nil
		callback()
	end
	scheduler.now_ms = target_ms
end

--- Restore real debounce timers and discard pending test callbacks.
---@return nil
function M.reset()
	local scheduler = M.state.scheduler
	if scheduler then
		for _, timer in ipairs(scheduler.timers) do
			timer:close()
		end
	end
	M.state.scheduler = nil
end

--- Schedule a callback after a quiet period, reusing the caller's timer when present.
---@param timer uv.uv_timer_t?
---@param delay_ms integer
---@param callback fun()
---@return uv.uv_timer_t
function M.schedule(timer, delay_ms, callback)
	local scheduler = M.state.scheduler
	if scheduler then
		if not is_test_timer(timer) then
			timer = new_test_timer()
		end
	elseif is_test_timer(timer) then
		timer = nil
	end
	timer = timer or assert(vim.uv.new_timer())
	timer:stop()
	timer:start(delay_ms, 0, scheduler and callback or vim.schedule_wrap(callback))
	return timer
end

return M
