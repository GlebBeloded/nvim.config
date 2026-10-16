-- Usage previews mirror real buffer text and highlighting without loading files or attaching clients.
local M = {}

local MAX_DISK_LINES = 10000
local MAX_HIGHLIGHT_BYTES = 1024 * 1024
local namespace = vim.api.nvim_create_namespace("gleb_references_preview")

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

---@param win integer
---@param usage gleb.references.TreeNode
---@return nil
function M.center(win, usage)
	local buf = vim.api.nvim_win_get_buf(win)
	local line_count = vim.api.nvim_buf_line_count(buf)
	local lnum = math.min(assert(usage.lnum, "selected reference has no line"), line_count)
	vim.wo[win].number = true
	vim.wo[win].cursorline = true
	vim.wo[win].cursorlineopt = "number"
	vim.api.nvim_win_set_cursor(win, { lnum, 0 })
	vim.api.nvim_win_call(win, function()
		vim.cmd("normal! zz")
	end)
end

return M
