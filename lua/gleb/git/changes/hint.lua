-- Branch hint owns the panel-relative footer and its scroll space; shortcut labels stay live from the action store.

local M = {}

local action_rows = require("gleb.find_action.rows")

local namespace = vim.api.nvim_create_namespace("gleb_changes_hint")

---@class ChangesHint
---@field buf integer
---@field win integer
---@field resize_autocmd integer

---@param id string
---@return string
local function shortcut(id)
	local store = assert(require("gleb.actions").state.store, "actions are not set up")
	local lhs = assert(store.last_good[id], "shortcut is not configured")[1]
	return action_rows.physical_label(lhs)
end

---@param view ChangesView
---@return string
local function hint_text(view)
	local mode = view.commit_view and "Files" or "Commits"
	return string.format("%s %s · Next tab %s", mode, shortcut("changes.toggle_commits"), shortcut("changes.review"))
end

---@param view ChangesView
---@return nil
local function add_scroll_space(view)
	vim.api.nvim_buf_clear_namespace(view.buf, namespace, 0, -1)
	vim.bo[view.buf].modifiable = true
	vim.api.nvim_buf_set_lines(view.buf, #view.rows, -1, false, { "" })
	vim.bo[view.buf].modifiable = false
	local last = math.max(#view.rows - 1, 0)
	vim.api.nvim_buf_set_extmark(view.buf, namespace, last, 0, {
		virt_lines = { { { "", "FileTreeNormal" } }, { { "", "FileTreeNormal" } } },
	})
end

---@param view ChangesView
---@return nil
local function layout(view)
	local state = view.hint
	if not state or not vim.api.nvim_win_is_valid(view.win) or not vim.api.nvim_win_is_valid(state.win) then
		return
	end
	local width = vim.api.nvim_win_get_width(view.win)
	local height = vim.api.nvim_win_get_height(view.win)
	vim.api.nvim_win_set_config(state.win, {
		relative = "win",
		win = view.win,
		row = math.max(height - 3, 0),
		col = 0,
		width = width,
		height = 2,
	})

	local text = hint_text(view)
	local padding = math.max(width - vim.fn.strdisplaywidth(text) - 1, 0)
	vim.bo[state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, { ("─"):rep(width), (" "):rep(padding) .. text .. " " })
	vim.bo[state.buf].modifiable = false
	vim.api.nvim_buf_clear_namespace(state.buf, namespace, 0, -1)
	vim.api.nvim_buf_set_extmark(state.buf, namespace, 0, 0, {
		end_col = #vim.api.nvim_buf_get_lines(state.buf, 0, 1, false)[1],
		hl_group = "PickerBorder",
	})
	vim.api.nvim_buf_set_extmark(state.buf, namespace, 1, padding, {
		end_col = padding + #text,
		hl_group = "PickerHint",
	})
end

---@param view ChangesView
---@return nil
local function open_hint(view)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	local win = vim.api.nvim_open_win(buf, false, {
		relative = "win",
		win = view.win,
		row = math.max(vim.api.nvim_win_get_height(view.win) - 3, 0),
		col = 0,
		width = vim.api.nvim_win_get_width(view.win),
		height = 2,
		focusable = false,
		style = "minimal",
		border = "none",
	})
	vim.wo[win].winhighlight = "Normal:FileTreeNormal"
	view.hint = { buf = buf, win = win, resize_autocmd = 0 }
	view.hint.resize_autocmd = vim.api.nvim_create_autocmd({ "WinResized", "VimResized" }, {
		group = "gleb_changes",
		callback = function()
			layout(view)
		end,
	})
	layout(view)
end

--- Close the Branch footer and remove its virtual scroll space.
---@param view ChangesView
---@return nil
function M.close(view)
	vim.api.nvim_buf_clear_namespace(view.buf, namespace, 0, -1)
	local state = view.hint
	if not state then
		return
	end
	pcall(vim.api.nvim_del_autocmd, state.resize_autocmd)
	if vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_close(state.win, true)
	end
	if vim.api.nvim_buf_is_valid(state.buf) then
		vim.api.nvim_buf_delete(state.buf, { force = true })
	end
	view.hint = nil
end

--- Keep the cursor above the two rows covered by the Branch footer.
---@param view ChangesView
---@return nil
function M.ensure_cursor(view)
	if not view.hint or not vim.api.nvim_win_is_valid(view.win) then
		return
	end
	local available = math.max(vim.api.nvim_win_get_height(view.win) - 3, 1)
	local cursor = vim.api.nvim_win_get_cursor(view.win)[1]
	if cursor > #view.rows then
		cursor = #view.rows
		vim.api.nvim_win_set_cursor(view.win, { cursor, 0 })
	end
	vim.api.nvim_win_call(view.win, function()
		local saved = vim.fn.winsaveview()
		local minimum_topline = math.max(cursor - available + 1, 1)
		if saved.topline < minimum_topline then
			saved.topline = minimum_topline
			vim.fn.winrestview(saved)
		end
	end)
end

--- Match the footer to the active tab and latest rendered rows.
---@param view ChangesView
---@return nil
function M.update(view)
	if view.active_tab ~= "branch" then
		M.close(view)
		return
	end
	add_scroll_space(view)
	if not view.hint then
		open_hint(view)
	else
		layout(view)
	end
	M.ensure_cursor(view)
end

return M
