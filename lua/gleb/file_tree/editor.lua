-- Project-tree editor selection shares the canonical tool-window tracking state.

local M = {}

local windows = require("gleb.tree.windows")

M.state = windows.state

--- Return whether a window can host an editor buffer.
---@param win integer
---@return boolean
function M.is_eligible(win)
	return windows.is_eligible_editor(win)
end

--- Remember the current window when it can host an editor buffer.
---@return nil
function M.remember()
	local win = vim.api.nvim_get_current_win()
	if M.is_eligible(win) then
		windows.state.last_editor_by_tab[vim.api.nvim_get_current_tabpage()] = win
	end
end

--- Select an eligible editor window for a left-side tool view.
---@param view { tab: integer, win: integer }
---@param replace_dashboard? boolean
---@return integer
function M.select(view, replace_dashboard)
	return windows.eligible_editor(view, replace_dashboard)
end

--- Count editor windows in a tab page.
---@param tab integer
---@return integer
function M.count(tab)
	return vim.iter(vim.api.nvim_tabpage_list_wins(tab)):fold(0, function(count, win)
		return count + (M.is_eligible(win) and 1 or 0)
	end)
end

--- Clear shared editor-window state.
---@return nil
function M.reset()
	windows.reset()
	M.state = windows.state
end

return M
