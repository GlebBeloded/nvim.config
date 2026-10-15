-- Captures editor state once so every action operation observes the same invocation.

local M = {}

local VISUAL_MODES = { v = true, V = true, ["\22"] = true }

---@return gleb.ActionSelection
local function capture_selection()
	local anchor = vim.fn.getpos("v")
	local cursor = vim.api.nvim_win_get_cursor(0)
	local first = { anchor[2], anchor[3] - 1 }
	local last = { cursor[1], cursor[2] }
	if first[1] > last[1] or (first[1] == last[1] and first[2] > last[2]) then
		first, last = last, first
	end
	return { start = first, finish = last }
end

---@return gleb.ActionContext
function M.capture()
	local mode = vim.fn.mode(1)
	return {
		win = vim.api.nvim_get_current_win(),
		buf = vim.api.nvim_get_current_buf(),
		cursor = vim.api.nvim_win_get_cursor(0),
		mode = mode,
		count = vim.v.count,
		selection = VISUAL_MODES[mode] and capture_selection() or nil,
	}
end

--- Prefix native `keys` with the invocation's count, as a mapping's rhs receives the typed count.
---@param ctx gleb.ActionContext
---@param keys string
---@return string
function M.counted(ctx, keys)
	return (ctx.count > 0 and tostring(ctx.count) or "") .. keys
end

---@param ctx gleb.ActionContext
---@return boolean
local function restore_target(ctx)
	if not vim.api.nvim_win_is_valid(ctx.win) or not vim.api.nvim_buf_is_valid(ctx.buf) then
		return false
	end
	if vim.api.nvim_win_get_buf(ctx.win) ~= ctx.buf then
		return false
	end
	vim.api.nvim_set_current_win(ctx.win)
	return pcall(vim.api.nvim_win_set_cursor, ctx.win, ctx.cursor)
end

---@param ctx gleb.ActionContext
local function restore_selection(ctx)
	local selection = ctx.selection
	if not selection then
		return
	end
	local current_mode = vim.fn.mode(1)
	if current_mode == ctx.mode and vim.deep_equal(capture_selection(), selection) then
		return
	end
	if VISUAL_MODES[current_mode] then
		vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
	end
	vim.api.nvim_buf_set_mark(ctx.buf, "<", selection.start[1], selection.start[2], {})
	vim.api.nvim_buf_set_mark(ctx.buf, ">", selection.finish[1], selection.finish[2], {})
	vim.api.nvim_win_set_cursor(ctx.win, selection.start)
	vim.cmd.normal({ args = { ctx.mode }, bang = true })
	vim.api.nvim_win_set_cursor(ctx.win, selection.finish)
end

---@param action gleb.Action
---@return function
function M.invoke(action)
	return function()
		M.run(action, M.capture())
	end
end

---@param action gleb.Action
---@param ctx gleb.ActionContext
---@return boolean
function M.run(action, ctx)
	if not restore_target(ctx) then
		return false
	end
	restore_selection(ctx)
	action.run(ctx)
	return true
end

---@param action gleb.Action
---@param ctx gleb.ActionContext
---@return boolean
function M.is_available(action, ctx)
	return not action.when or action.when(ctx)
end

---@param action gleb.Action
---@param ctx gleb.ActionContext
---@return boolean?
function M.get_toggle(action, ctx)
	if action.toggle then
		return action.toggle.get(ctx)
	end
	return nil
end

---@param action gleb.Action
---@param ctx gleb.ActionContext
---@param value boolean
function M.set_toggle(action, ctx, value)
	if action.toggle then
		action.toggle.set(ctx, value)
	end
end

return M
