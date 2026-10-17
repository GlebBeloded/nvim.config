-- Real-window construction for the aligned diff view.
-- The right side keeps the user's file buffer while the left side is an owned scratch buffer.

local M = {}

local STATUSCOLUMN = "%!v:lua.require'gleb.diff.view.render'.statuscolumn()"
local FOLDTEXT = "v:lua.require'gleb.diff.view.render'.foldtext()"
local WINDOW_OPTIONS = {
	"number",
	"relativenumber",
	"cursorline",
	"wrap",
	"list",
	"signcolumn",
	"foldcolumn",
	"foldmethod",
	"foldenable",
	"foldlevel",
	"foldtext",
	"fillchars",
	"winhighlight",
	"statuscolumn",
	"winbar",
}

---@param win integer
---@return table<string, unknown>
local function window_options(win)
	local options = {}
	for _, name in ipairs(WINDOW_OPTIONS) do
		options[name] = vim.wo[win][name]
	end
	return options
end

---@param win integer
local function configure_window(win)
	local wo = vim.wo[win]
	wo.number = false
	wo.relativenumber = false
	wo.cursorline = false
	wo.wrap = false
	wo.list = false
	wo.signcolumn = "no"
	wo.foldcolumn = "0"
	wo.foldmethod = "manual"
	wo.foldenable = true
	wo.foldlevel = 0
	wo.foldtext = FOLDTEXT
	wo.fillchars = "fold:~,vert: ,eob: "
	wo.winhighlight = "WinBar:DiffViewHeader,WinBarNC:DiffViewHeader,Folded:DiffViewFold,EndOfBuffer:Normal"
	wo.statuscolumn = STATUSCOLUMN
end

---@param view gleb.diff.view.View
local function add_folds(view)
	local has_ufo, ufo = pcall(require, "ufo")
	if has_ufo then
		ufo.detach(view.left_buf)
		ufo.detach(view.right_buf)
	end
	for _, side in ipairs({ "left", "right" }) do
		local win = side == "left" and view.left_win or view.right_win
		vim.api.nvim_win_call(win, function()
			vim.cmd("silent! normal! zE")
			for _, fold in ipairs(view.layout.folds) do
				local first = side == "left" and fold.start1 or fold.start2
				local last = side == "left" and fold.end1 or fold.end2
				vim.cmd(("%d,%dfold"):format(first, last))
			end
		end)
	end
end

---@param relpath string
---@param lines string[]
---@param filetype string
---@return integer
local function left_buffer(relpath, lines, filetype)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "gleb-diff://HEAD/" .. relpath)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = "gleb-diff"
	local language = vim.treesitter.language.get_lang(filetype)
	if language then
		pcall(vim.treesitter.start, buf, language)
	end
	return buf
end

---@param view gleb.diff.view.View
local function resize(view)
	if not vim.api.nvim_win_is_valid(view.left_win) or not vim.api.nvim_win_is_valid(view.right_win) then
		return
	end
	local width = vim.api.nvim_win_get_width(view.left_win) + vim.api.nvim_win_get_width(view.right_win) + 1
	vim.api.nvim_win_set_width(view.left_win, math.floor(width * 0.4))
end

---@param view gleb.diff.view.View
local function create_autocmds(view)
	local group = vim.api.nvim_create_augroup("gleb_diff_view_" .. view.ns, { clear = true })
	view.augroup = group
	vim.api.nvim_create_autocmd("VimResized", {
		group = group,
		callback = function()
			resize(view)
		end,
	})
	vim.api.nvim_create_autocmd("WinClosed", {
		group = group,
		pattern = { tostring(view.left_win), tostring(view.right_win) },
		callback = function()
			vim.schedule(function()
				require("gleb.diff.view").close(view)
			end)
		end,
	})
end

---@param view gleb.diff.view.View
---@param width integer
local function finish(view, width)
	view.left_buf = left_buffer(view.relpath, view.left, view.filetype)
	vim.bo[view.left_buf].tabstop = vim.bo[view.right_buf].tabstop
	vim.api.nvim_win_set_buf(view.left_win, view.left_buf)
	vim.api.nvim_win_set_width(view.left_win, math.floor(width * 0.4))

	configure_window(view.left_win)
	configure_window(view.right_win)
	vim.wo[view.left_win].winbar = " " .. view.labels.left
	vim.wo[view.right_win].winbar = string.rep(" ", 16) .. view.labels.right
	add_folds(view)
	create_autocmds(view)
end

---@param view gleb.diff.view.View
function M.open(view)
	view.origin_win = vim.api.nvim_get_current_win()
	vim.cmd.tabnew()
	view.tab = vim.api.nvim_get_current_tabpage()
	view.owns_tab = true
	view.right_win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(view.right_win, view.right_buf)
	local width = vim.api.nvim_win_get_width(view.right_win)
	vim.cmd("leftabove vsplit")
	view.left_win = vim.api.nvim_get_current_win()
	finish(view, width)
	vim.api.nvim_set_current_win(view.right_win)
end

---@param view gleb.diff.view.View
---@param win integer
function M.show(view, win)
	local current = vim.api.nvim_get_current_win()
	view.origin_win = current
	view.tab = vim.api.nvim_win_get_tabpage(win)
	view.owns_tab = false
	view.right_win = win
	view.right_restore = {
		buf = vim.api.nvim_win_get_buf(win),
		options = window_options(win),
	}
	local width = vim.api.nvim_win_get_width(win)
	vim.api.nvim_win_set_buf(win, view.right_buf)
	vim.api.nvim_set_current_win(win)
	vim.cmd("leftabove vsplit")
	view.left_win = vim.api.nvim_get_current_win()
	finish(view, width)
	if vim.api.nvim_win_is_valid(current) then
		vim.api.nvim_set_current_win(current)
	end
end

---@param view gleb.diff.view.View
function M.restore(view)
	local restore = view.right_restore
	if not restore or not vim.api.nvim_win_is_valid(view.right_win) then
		return
	end
	vim.api.nvim_win_set_buf(view.right_win, restore.buf)
	for name, value in pairs(restore.options) do
		vim.wo[view.right_win][name] = value
	end
end

return M
