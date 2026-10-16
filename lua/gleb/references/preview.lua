-- Usage previews mirror real buffer text and highlighting without loading files or attaching clients.
local M = {}

local MAX_DISK_LINES = 10000
local MAX_HIGHLIGHT_BYTES = 1024 * 1024
local MIN_NUMBER_WIDTH = 3
local TABSTOP = 4
local CLIPPED = "…"
local namespace = vim.api.nvim_create_namespace("gleb_references_preview")
local clipped_namespace = vim.api.nvim_create_namespace("gleb_references_preview_clipped")

---@param filename string
---@return integer?
local function loaded_buffer(filename)
	local target = vim.fs.normalize(filename)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			local name = vim.api.nvim_buf_get_name(buf)
			if name ~= "" and vim.fs.normalize(name) == target then
				return buf
			end
		end
	end
end

---@param filename string
---@return string[]
local function source_lines(filename)
	local source_buf = loaded_buffer(filename)
	if source_buf then
		return vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
	end
	return vim.fn.readfile(filename, "", MAX_DISK_LINES)
end

---@param buf integer
---@param filetype string
---@param byte_count integer
local function start_highlighting(buf, filetype, byte_count)
	pcall(vim.treesitter.stop, buf)
	vim.bo[buf].syntax = ""
	local language = vim.treesitter.language.get_lang(filetype) or filetype
	local parser_exists, added = pcall(vim.treesitter.language.add, language)
	if byte_count <= MAX_HIGHLIGHT_BYTES and parser_exists and added then
		pcall(vim.treesitter.start, buf, language)
		return
	end
	vim.bo[buf].syntax = filetype
end

---@param buf integer
---@param usage gleb.references.TreeNode
---@param usages gleb.references.Usage[]
---@param symbol string
---@return nil
function M.render(buf, usage, usages, symbol)
	local filename = vim.uri_to_fname(assert(usage.uri, "selected reference has no URI"))
	local lines = source_lines(filename)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].tabstop = TABSTOP

	vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	for _, item in ipairs(usages) do
		if item.uri == usage.uri and item.lnum <= #lines then
			local start_col = math.max(item.col - 1, 0)
			vim.api.nvim_buf_set_extmark(buf, namespace, item.lnum - 1, start_col, {
				end_col = start_col + #symbol,
				hl_group = "Search",
			})
		end
	end

	local filetype = usage.filetype or vim.filetype.match({ filename = filename }) or ""
	start_highlighting(buf, filetype, #table.concat(lines, "\n"))
end

---@param usage gleb.references.TreeNode
---@return string
local function heading(usage)
	local label = string.format("%s:%d", assert(usage.path, "selected reference has no path"), usage.lnum)
	return "%#MiniPickNormal# %#PickerSecondary#" .. (label:gsub("%%", "%%%%")) .. "%#MiniPickNormal#"
end

---@param line_count integer
---@param lnum integer the usage's line, numbered in [CursorLineNr]
---@return string format
---@return integer width cells, known before the first redraw measures it
local function number_column(line_count, lnum)
	local width = math.max(#tostring(line_count), MIN_NUMBER_WIDTH)
	local number_group = string.format("%%{%%v:lnum == %d ? '%%#CursorLineNr#' : '%%#PickerSecondary#'%%}", lnum)
	return string.format("%%#MiniPickNormal# %s%%%dl%%#MiniPickNormal#  ", number_group, width), width + 3
end

--- Mark lines cut by the window edge, keeping the clipped cell's own highlight.
---@param win integer
---@param topline integer
---@param text_width integer
local function mark_clipped(win, topline, text_width)
	local buf = vim.api.nvim_win_get_buf(win)
	local last = math.min(topline + vim.fn.getwininfo(win)[1].height - 1, vim.api.nvim_buf_line_count(buf))
	vim.api.nvim_buf_clear_namespace(buf, clipped_namespace, 0, -1)
	for lnum = topline, last do
		local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]
		local width = vim.api.nvim_win_call(win, function()
			return vim.fn.strdisplaywidth(line)
		end)
		if width > text_width then
			vim.api.nvim_buf_set_extmark(buf, clipped_namespace, lnum - 1, 0, {
				virt_text = { { CLIPPED } },
				virt_text_win_col = text_width - 1,
				hl_mode = "combine",
			})
		end
	end
end

---@param win integer
---@param usage gleb.references.TreeNode
---@return nil
function M.center(win, usage)
	local buf = vim.api.nvim_win_get_buf(win)
	local line_count = vim.api.nvim_buf_line_count(buf)
	local lnum = math.min(assert(usage.lnum, "selected reference has no line"), line_count)
	vim.wo[win].winbar = heading(usage)
	vim.wo[win].number = true
	local number_format, number_width = number_column(line_count, lnum)
	vim.wo[win].statuscolumn = number_format
	vim.wo[win].cursorline = true
	vim.wo[win].cursorlineopt = "number"
	vim.wo[win].wrap = false
	vim.wo[win].scrolloff = 0
	local rows = vim.fn.getwininfo(win)[1].height
	local topline = math.max(lnum - math.floor((rows - 1) / 2), 1)
	vim.api.nvim_win_call(win, function()
		vim.fn.winrestview({ lnum = lnum, col = 0, topline = topline })
	end)
	mark_clipped(win, topline, vim.api.nvim_win_get_width(win) - number_width)
end

return M
