-- Changes view owns the fixed left window while the model and renderer own its rows.

local M = {}

local fs = require("gleb.file_tree.fs")
local git = require("gleb.git.changes.git")
local model = require("gleb.git.changes.model")
local render = require("gleb.git.changes.render")
local settings = require("gleb.file_tree.settings")

local WIDTH = 35
local augroup = vim.api.nvim_create_augroup("gleb_changes", { clear = true })

---@class ChangesView
---@field tab integer
---@field root string
---@field buf integer
---@field win integer
---@field editor_win integer
---@field rows ChangesRow[]

---@param buf integer
---@return nil
local function configure_buffer(buf)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].buflisted = false
	vim.bo[buf].filetype = "gleb-changes"
end

---@param win integer
---@return nil
local function configure_window(win)
	vim.wo[win].winfixwidth = true
	vim.wo[win].cursorline = true
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].foldcolumn = "0"
	vim.wo[win].foldenable = false
	vim.wo[win].statuscolumn = ""
	vim.wo[win].wrap = false
	vim.wo[win].list = false
	vim.wo[win].spell = false
	vim.wo[win].winhighlight = "Normal:FileTreeNormal,CursorLine:FileTreeCursorLine,EndOfBuffer:FileTreeNormal"
	vim.api.nvim_win_set_width(win, WIDTH)
end

---@param view ChangesView
---@param selected_path string
---@return nil
local function select_file(view, selected_path)
	local selected_relative = selected_path ~= "" and selected_path:sub(#view.root + 2) or ""
	local first_file
	for index, row in ipairs(view.rows) do
		if row.kind == "file" then
			first_file = first_file or index
			if row.path == selected_relative then
				vim.api.nvim_win_set_cursor(view.win, { index, 0 })
				return
			end
		end
	end
	if first_file then
		vim.api.nvim_win_set_cursor(view.win, { first_file, 0 })
	end
end

---@param view ChangesView
---@return nil
local function forget(view)
	local changes = require("gleb.git.changes")
	if changes.state.by_tab[view.tab] == view then
		changes.state.by_tab[view.tab] = nil
	end
end

--- Close one Changes view.
---@param view ChangesView
---@return nil
function M.close(view)
	forget(view)
	if vim.api.nvim_win_is_valid(view.editor_win) then
		vim.api.nvim_set_current_win(view.editor_win)
	end
	if vim.api.nvim_win_is_valid(view.win) then
		vim.api.nvim_win_close(view.win, true)
	end
	if vim.api.nvim_buf_is_valid(view.buf) then
		vim.api.nvim_buf_delete(view.buf, { force = true })
	end
end

--- Open and populate a Changes view in the current tab.
---@param root string
---@param selected_path string
---@return ChangesView
function M.open(root, selected_path)
	local changes = require("gleb.git.changes")
	local tab = vim.api.nvim_get_current_tabpage()
	local editor_win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, ("gleb-changes://%s#%d"):format(root, tab))
	configure_buffer(buf)

	vim.cmd("topleft vertical " .. WIDTH .. " split")
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	configure_window(win)

	---@type ChangesView
	local view = {
		tab = tab,
		root = fs.normalize(root),
		buf = buf,
		win = win,
		editor_win = editor_win,
		rows = {},
	}
	changes.state.by_tab[tab] = view
	vim.api.nvim_create_autocmd("WinClosed", {
		group = augroup,
		pattern = tostring(win),
		once = true,
		callback = function()
			forget(view)
		end,
	})

	git.refresh(view.root, function(result)
		if changes.state.by_tab[tab] ~= view or not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		if result.code ~= 0 then
			vim.notify("Git status failed: " .. vim.trim(result.stderr or ""), vim.log.levels.ERROR)
			return
		end
		view.rows = model.rows(result.stdout or "", settings.load().nesting.rules)
		render.draw(buf, view.rows, WIDTH)
		if vim.api.nvim_win_is_valid(win) then
			select_file(view, fs.normalize(selected_path))
		end
	end)
	return view
end

return M
