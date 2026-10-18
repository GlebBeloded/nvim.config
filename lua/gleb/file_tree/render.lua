-- Project-tree rendering keeps IntelliJ-like spacing, icons and palette-owned highlights in one place.

local M = {}

local palette = require("gleb.colors.gruvbox-material.palette")
local has_devicons, devicons = pcall(require, "nvim-web-devicons")

local EXPANDED = ""
local COLLAPSED = ""
local FOLDER_OPEN = ""
local FOLDER_CLOSED = ""
local FOLDER_EMPTY = "󰉖"
local FILE = ""

---@type table<string, string>
local STATUS_GROUPS = {
	modified = "FileTreeGitModified",
	added = "FileTreeGitAdded",
	untracked = "FileTreeGitUntracked",
	deleted = "FileTreeGitDeleted",
	renamed = "FileTreeGitRenamed",
	conflict = "FileTreeGitConflict",
}

M.namespace = vim.api.nvim_create_namespace("gleb_file_tree_render")

local function apply_highlights()
	local background = palette.background
	local foreground = palette.foreground
	vim.api.nvim_set_hl(0, "FileTreeNormal", { link = "Normal" })
	vim.api.nvim_set_hl(0, "FileTreeRoot", { fg = foreground.fg1, bold = true })
	vim.api.nvim_set_hl(0, "FileTreeRootPath", { fg = foreground.grey1 })
	vim.api.nvim_set_hl(0, "FileTreeExpander", { fg = foreground.grey1 })
	vim.api.nvim_set_hl(0, "FileTreeFolderIcon", { fg = foreground.blue })
	vim.api.nvim_set_hl(0, "FileTreeFolderName", { fg = foreground.fg0 })
	vim.api.nvim_set_hl(0, "FileTreeFileName", { fg = foreground.fg0 })
	vim.api.nvim_set_hl(0, "FileTreeIgnored", { fg = foreground.grey0, italic = true })
	vim.api.nvim_set_hl(0, "FileTreeGitModified", { fg = foreground.blue })
	vim.api.nvim_set_hl(0, "FileTreeGitAdded", { fg = foreground.green })
	vim.api.nvim_set_hl(0, "FileTreeGitUntracked", { fg = foreground.orange })
	vim.api.nvim_set_hl(0, "FileTreeGitDeleted", { fg = foreground.grey1, strikethrough = true })
	vim.api.nvim_set_hl(0, "FileTreeGitRenamed", { fg = foreground.aqua })
	vim.api.nvim_set_hl(0, "FileTreeGitConflict", { fg = foreground.red })
	vim.api.nvim_set_hl(0, "FileTreeCursorLine", { bg = background.bg1 })
	vim.api.nvim_set_hl(0, "FileTreeHiddenCursor", { blend = 100 })
end

---@class FileTreeRenderSegment
---@field text string
---@field group string?

---@param row FileTreeRow
---@return FileTreeRenderSegment[]
local function root_segments(row)
	return {
		{ text = " " },
		{ text = EXPANDED, group = "FileTreeExpander" },
		{ text = " " },
		{ text = FOLDER_OPEN, group = "FileTreeFolderIcon" },
		{ text = " " },
		{ text = row.label, group = "FileTreeRoot" },
		{ text = "  " },
		{ text = vim.fn.fnamemodify(row.path, ":~"), group = "FileTreeRootPath" },
	}
end

---@param row FileTreeRow
---@return FileTreeRenderSegment[]
local function directory_segments(row)
	local expander = row.empty and " " or row.expanded and EXPANDED or COLLAPSED
	local icon = row.empty and FOLDER_EMPTY or row.expanded and FOLDER_OPEN or FOLDER_CLOSED
	local icon_group = row.ignored and "FileTreeIgnored" or "FileTreeFolderIcon"
	local name_group = row.ignored and "FileTreeIgnored" or STATUS_GROUPS[row.status] or "FileTreeFolderName"
	return {
		{ text = string.rep(" ", 3 + 2 * row.depth) },
		{ text = expander, group = row.empty and nil or "FileTreeExpander" },
		{ text = " " },
		{ text = icon, group = icon_group },
		{ text = " " },
		{ text = row.label, group = name_group },
	}
end

---@param row FileTreeRow
---@return string icon
---@return string group
local function file_icon(row)
	if has_devicons then
		local icon, group = devicons.get_icon(row.label, nil, { default = true })
		if icon and group then
			return icon, group
		end
	end
	return FILE, "FileTreeFileName"
end

---@param row FileTreeRow
---@return FileTreeRenderSegment[]
local function file_segments(row)
	local icon, icon_group = file_icon(row)
	if row.ignored then
		icon_group = "FileTreeIgnored"
	end
	local name_group = row.ignored and "FileTreeIgnored" or STATUS_GROUPS[row.status] or "FileTreeFileName"
	if row.nest_children then
		return {
			{ text = string.rep(" ", 3 + 2 * row.depth) },
			{ text = row.nest_expanded and EXPANDED or COLLAPSED, group = "FileTreeExpander" },
			{ text = " " },
			{ text = icon, group = icon_group },
			{ text = " " },
			{ text = row.label, group = name_group },
		}
	end
	return {
		{ text = string.rep(" ", 5 + 2 * row.depth) },
		{ text = icon, group = icon_group },
		{ text = " " },
		{ text = row.label, group = name_group },
	}
end

---@param buf integer
---@param row_index integer
---@param segments FileTreeRenderSegment[]
---@return nil
local function add_segments(buf, row_index, segments)
	local start_col = 0
	for _, segment in ipairs(segments) do
		if segment.group then
			vim.api.nvim_buf_set_extmark(buf, M.namespace, row_index, start_col, {
				end_col = start_col + #segment.text,
				hl_group = segment.group,
			})
		end
		start_col = start_col + #segment.text
	end
end

--- Draw project-tree rows into a buffer.
---@param buf integer
---@param rows FileTreeRow[]
---@return nil
function M.draw(buf, rows)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_clear_namespace(buf, M.namespace, 0, -1)
	local rendered = {}
	local lines = {}
	for index, row in ipairs(rows) do
		local segments = row.kind == "root" and root_segments(row)
			or row.kind == "directory" and directory_segments(row)
			or file_segments(row)
		rendered[index] = segments
		lines[index] = vim.iter(segments):fold("", function(line, segment)
			return line .. segment.text
		end)
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	for index, segments in ipairs(rendered) do
		add_segments(buf, index - 1, segments)
	end
	vim.bo[buf].modifiable = false
end

--- Define project-tree highlights and restore them after colorscheme changes.
---@return nil
function M.setup()
	apply_highlights()
	local group = vim.api.nvim_create_augroup("gleb_file_tree_highlights", { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = apply_highlights })
end

return M
