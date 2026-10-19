-- Event handling and synchronization for the owned two-side diff view.
-- View callbacks are injected so this lifecycle module does not depend on the public API.

local debounce = require("gleb.util.debounce")
local layout = require("gleb.diff.view.layout")

local M = {}

---@class gleb.diff.view.AutocmdOptions
---@field by_win table<integer, gleb.diff.view.View>
---@field debounce_ms integer
---@field redraw fun(view: gleb.diff.view.View)
---@field refresh_index fun(view: gleb.diff.view.View)

---@type table<gleb.diff.view.View, { cursor?: { win: integer, line: integer, col: integer }, scroll?: { win: integer, topline: integer, topfill: integer, leftcol: integer } }>
local sync_states = setmetatable({}, { __mode = "k" })

---@param view gleb.diff.view.View
---@param options gleb.diff.view.AutocmdOptions
local function schedule_redraw(view, options)
	if view.closing then
		return
	end
	view.timer = debounce.schedule(view.timer, options.debounce_ms, function()
		options.redraw(view)
	end)
end

---@param view gleb.diff.view.View
---@param options gleb.diff.view.AutocmdOptions
local function attach(view, options)
	local function on_lines()
		if view.closing then
			return true
		end
		schedule_redraw(view, options)
	end
	local function on_detach()
		view.attached = false
	end
	view.attached = vim.api.nvim_buf_attach(view.right_buf, false, {
		on_lines = on_lines,
		on_detach = on_detach,
	})
end

---@param view gleb.diff.view.View
---@param source_win integer
local function sync_windows(view, source_win)
	if view.syncing or not vim.api.nvim_win_is_valid(source_win) then
		return
	end
	local source_side = source_win == view.left_win and "left" or "right"
	local peer_win = source_side == "left" and view.right_win or view.left_win
	if not vim.api.nvim_win_is_valid(peer_win) then
		return
	end
	local source_view = vim.api.nvim_win_call(source_win, vim.fn.winsaveview)
	local source_cursor = vim.api.nvim_win_get_cursor(source_win)
	local peer_line = layout.transfer_line(view.layout, source_side, source_cursor[1])
	local peer_count = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(peer_win))
	local peer_topline = layout.transfer_line(view.layout, source_side, source_view.topline)
	peer_line = math.min(math.max(peer_line, 1), peer_count)
	local state = sync_states[view] or {}
	sync_states[view] = state

	view.syncing = true
	local peer_cursor = vim.api.nvim_win_get_cursor(peer_win)
	if peer_cursor[1] ~= peer_line or peer_cursor[2] ~= source_cursor[2] then
		state.cursor = { win = peer_win, line = peer_line, col = source_cursor[2] }
		vim.api.nvim_win_set_cursor(peer_win, { peer_line, source_cursor[2] })
	end
	local target_topline = math.min(math.max(peer_topline, 1), peer_count)
	state.scroll = {
		win = peer_win,
		topline = target_topline,
		topfill = source_view.topfill,
		leftcol = source_view.leftcol,
	}
	vim.api.nvim_win_call(peer_win, function()
		vim.fn.winrestview({
			topline = target_topline,
			topfill = source_view.topfill,
			leftcol = source_view.leftcol,
		})
	end)
	view.syncing = false
end

---@param options gleb.diff.view.AutocmdOptions
---@param args vim.api.keyset.create_autocmd.callback_args
local function on_scrolled(options, args)
	local win = tonumber(args.match) --[[@as integer?]]
	if not win then
		return
	end
	local view = options.by_win[win]
	if view then
		local state = sync_states[view]
		local synced = state and state.scroll or nil
		if synced and synced.win == win then
			local actual = vim.api.nvim_win_call(win, vim.fn.winsaveview)
			state.scroll = nil
			if
				synced.topline == actual.topline
				and synced.topfill == actual.topfill
				and synced.leftcol == actual.leftcol
			then
				return
			end
		end
		sync_windows(view, win)
	end
end

---@param options gleb.diff.view.AutocmdOptions
local function on_cursor_moved(options)
	local win = vim.api.nvim_get_current_win()
	local view = options.by_win[win]
	if view then
		local cursor = vim.api.nvim_win_get_cursor(win)
		local state = sync_states[view]
		local synced = state and state.cursor or nil
		if synced and synced.win == win and synced.line == cursor[1] and synced.col == cursor[2] then
			state.cursor = nil
			return
		end
		if synced and synced.win == win then
			state.cursor = nil
		end
		sync_windows(view, win)
	end
end

--- Install interaction events and buffer change tracking for a diff view.
---@param view gleb.diff.view.View
---@param options gleb.diff.view.AutocmdOptions
---@return nil
function M.install(view, options)
	vim.api.nvim_create_autocmd("WinScrolled", {
		group = view.augroup,
		pattern = { tostring(view.left_win), tostring(view.right_win) },
		callback = function(args)
			on_scrolled(options, args)
		end,
	})
	for _, buf in ipairs({ view.left_buf, view.right_buf }) do
		vim.api.nvim_create_autocmd("CursorMoved", {
			group = view.augroup,
			buffer = buf,
			callback = function()
				on_cursor_moved(options)
			end,
		})
	end
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = view.augroup,
		buffer = view.right_buf,
		callback = function()
			schedule_redraw(view, options)
		end,
	})
	vim.api.nvim_create_autocmd("FocusGained", {
		group = view.augroup,
		callback = function()
			options.refresh_index(view)
		end,
	})
	attach(view, options)
end

--- Forget synchronization state owned by a closing view.
---@param view gleb.diff.view.View
---@return nil
function M.forget(view)
	sync_states[view] = nil
end

return M
