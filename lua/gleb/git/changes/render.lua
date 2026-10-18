-- Changes rendering owns the panel's fixed columns and semantic highlight spans.

local M = {}

local has_devicons, devicons = pcall(require, "nvim-web-devicons")

local EXPANDED = ""
local COLLAPSED = ""
local FOLDER_OPEN = ""
local FILE = ""
local ELLIPSIS = "…"
local RIGHT_MARGIN = 1

---@type table<string, string>
local STATUS_GROUPS = {
	modified = "FileTreeGitModified",
	added = "FileTreeGitAdded",
	untracked = "FileTreeGitUntracked",
	deleted = "FileTreeGitDeleted",
	renamed = "FileTreeGitRenamed",
	conflict = "FileTreeGitConflict",
}

M.namespace = vim.api.nvim_create_namespace("gleb_changes_render")

---@class ChangesRenderSegment
---@field text string
---@field group string?

---@param row ChangesRow
---@return ChangesRenderSegment[]
local function root_segments(row)
	local suffix = row.count == 1 and " file" or " files"
	return {
		{ text = " " },
		{ text = row.expanded == false and COLLAPSED or EXPANDED, group = "FileTreeExpander" },
		{ text = " " },
		{ text = row.checkbox or "", group = "ChangesCheckbox" },
		{ text = " " },
		{ text = row.label, group = "ChangesRoot" },
		{ text = " " },
		{ text = tostring(row.count) .. suffix, group = "ChangesCount" },
	}
end

---@param row ChangesRow
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

---@param row ChangesRow
---@return ChangesRenderSegment[]
local function directory_segments(row)
	return {
		{ text = string.rep(" ", 1 + 2 * row.depth) },
		{ text = row.expanded == false and COLLAPSED or EXPANDED, group = "FileTreeExpander" },
		{ text = " " },
		{ text = FOLDER_OPEN, group = "FileTreeFolderIcon" },
		{ text = " " },
		{ text = row.label, group = "FileTreeFolderName" },
		{ text = " " },
		{ text = tostring(row.count), group = "ChangesCount" },
	}
end

---@param segments ChangesRenderSegment[]
---@return integer
local function segments_width(segments)
	return vim.iter(segments):fold(0, function(width, segment)
		return width + vim.fn.strdisplaywidth(segment.text)
	end)
end

---@param text string
---@param width integer
---@return string kept text without the ellipsis
---@return boolean cut whether an ellipsis follows the kept text
local function truncate(text, width)
	if vim.fn.strdisplaywidth(text) <= width then
		return text, false
	end
	if width <= 1 then
		return "", width == 1
	end

	local result = {}
	local result_width = 0
	for index = 0, vim.fn.strchars(text) - 1 do
		local character = vim.fn.strcharpart(text, index, 1)
		local character_width = vim.fn.strdisplaywidth(character)
		if result_width + character_width > width - 1 then
			break
		end
		result[#result + 1] = character
		result_width = result_width + character_width
	end
	return table.concat(result), true
end

---@param row ChangesRow
---@param width integer
---@return ChangesRenderSegment[]
local function file_segments(row, width)
	local icon, icon_group = file_icon(row)
	local segments = {
		{ text = string.rep(" ", 1 + 2 * row.depth) },
		{
			text = row.fold_id and (row.expanded == false and COLLAPSED or EXPANDED) or " ",
			group = row.fold_id and "FileTreeExpander" or nil,
		},
		{ text = " " },
		{ text = row.checkbox or "", group = "ChangesCheckbox" },
		{ text = " " },
		{ text = icon, group = icon_group },
		{ text = " " },
	}
	local name_group = STATUS_GROUPS[row.status] or "FileTreeFileName"
	if row.added == nil or row.removed == nil then
		segments[#segments + 1] = { text = row.label, group = name_group }
		return segments
	end

	local added = "+" .. row.added
	local removed = "-" .. row.removed
	local stat_width = vim.fn.strdisplaywidth(added) + 1 + vim.fn.strdisplaywidth(removed)
	local name_width = math.max(1, width - RIGHT_MARGIN - segments_width(segments) - stat_width - 1)
	local name, cut = truncate(row.label, name_width)
	local name_cells = vim.fn.strdisplaywidth(name) + (cut and vim.fn.strdisplaywidth(ELLIPSIS) or 0)
	local padding = math.max(1, width - RIGHT_MARGIN - segments_width(segments) - name_cells - stat_width)
	segments[#segments + 1] = { text = name, group = name_group }
	if cut then
		segments[#segments + 1] = { text = ELLIPSIS, group = "ChangesCount" }
	end
	segments[#segments + 1] = { text = string.rep(" ", padding) }
	segments[#segments + 1] = { text = added, group = "ChangesStatAdded" }
	segments[#segments + 1] = { text = " " }
	segments[#segments + 1] = { text = removed, group = "ChangesStatRemoved" }
	return segments
end

---@param row ChangesRow
---@param width integer
---@return ChangesRenderSegment[]
local function segments_for(row, width)
	if row.kind == "root" then
		return root_segments(row)
	end
	if row.kind == "directory" then
		return directory_segments(row)
	end
	return file_segments(row, width)
end

---@param buf integer
---@param row_index integer
---@param segments ChangesRenderSegment[]
---@return nil
local function add_extmarks(buf, row_index, segments)
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

--- Draw Changes rows and their semantic highlights into a buffer.
---@param buf integer
---@param rows ChangesRow[]
---@param width integer
---@return nil
function M.draw(buf, rows, width)
	local rendered = {}
	local lines = {}
	for index, row in ipairs(rows) do
		local segments = segments_for(row, width)
		rendered[index] = segments
		lines[index] = vim.iter(segments):fold("", function(line, segment)
			return line .. segment.text
		end)
	end

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_clear_namespace(buf, M.namespace, 0, -1)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	for index, segments in ipairs(rendered) do
		add_extmarks(buf, index - 1, segments)
	end
	vim.bo[buf].modifiable = false
end

return M
