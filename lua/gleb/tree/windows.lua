-- Tree windows select a normal editor beside either left-docked tree without owning either feature's state.

local M = {}

---@class TreeWindowState
---@field last_editor_by_tab table<integer, integer>

---@type TreeWindowState
M.state = { last_editor_by_tab = {} }

---@param view { tab: integer, win: integer }
---@return integer
local function create_editor(view)
	vim.api.nvim_set_current_win(view.win)
	vim.cmd("rightbelow vnew")
	vim.cmd(
		"setlocal winfixwidth< cursorline< number< relativenumber< signcolumn< foldcolumn< foldenable< foldmethod< statuscolumn< wrap< list< spell< winhighlight<"
	)
	local win = vim.api.nvim_get_current_win()
	M.state.last_editor_by_tab[view.tab] = win
	return win
end

--- Return whether a window can host an editor buffer.
---@param win integer
---@return boolean
function M.is_eligible_editor(win)
	if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_config(win).relative ~= "" then
		return false
	end
	local buf = vim.api.nvim_win_get_buf(win)
	local filetype = vim.bo[buf].filetype
	local name = vim.api.nvim_buf_get_name(buf)
	return vim.bo[buf].buftype == ""
		and filetype ~= "gleb-file-tree"
		and filetype ~= "gleb-changes"
		and not vim.startswith(filetype, "Diffview")
		and not vim.startswith(name, "diffview://")
		and not vim.wo[win].diff
end

--- Select an eligible editor window for a left-side tree view.
---@param view { tab: integer, win: integer }
---@param replace_dashboard? boolean
---@return integer
function M.eligible_editor(view, replace_dashboard)
	local remembered = M.state.last_editor_by_tab[view.tab]
	if remembered and remembered ~= view.win and M.is_eligible_editor(remembered) then
		return remembered
	end
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(view.tab)) do
		if win ~= view.win and M.is_eligible_editor(win) then
			M.state.last_editor_by_tab[view.tab] = win
			return win
		end
	end
	if replace_dashboard then
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(view.tab)) do
			local buf = vim.api.nvim_win_get_buf(win)
			if win ~= view.win and vim.bo[buf].filetype == "alpha" then
				vim.api.nvim_win_set_buf(win, vim.api.nvim_create_buf(true, false))
				M.state.last_editor_by_tab[view.tab] = win
				return win
			end
		end
	end
	return create_editor(view)
end

--- Clear remembered editor windows.
---@return nil
function M.reset()
	M.state = { last_editor_by_tab = {} }
end

return M
