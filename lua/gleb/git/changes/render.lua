-- Changes rendering owns the panel's fixed columns and semantic highlight spans.

local M = {}

local EXPANDED = ""
local FOLDER_OPEN = ""
local FILE = ""
local UNCHECKED = "☐"

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
		{ text = EXPANDED, group = "FileTreeExpander" },
		{ text = " " },
		{ text = UNCHECKED, group = "ChangesCheckbox" },
		{ text = " " },
		{ text = row.label, group = "ChangesRoot" },
		{ text = " " },
		{ text = tostring(row.count) .. suffix, group = "ChangesCount" },
	}
end

---@param row ChangesRow
---@return ChangesRenderSegment[]
local function directory_segments(row)
	return {
		{ text = string.rep(" ", 1 + 2 * row.depth) },
		{ text = EXPANDED, group = "FileTreeExpander" },
		{ text = " " },
		{ text = FOLDER_OPEN, group = "FileTreeFolderIcon" },
		{ text = " " },
		{ text = row.label, group = "FileTreeFolderName" },
		{ text = " " },
		{ text = tostring(row.count), group = "ChangesCount" },
	}
end

---@param row ChangesRow
---@return ChangesRenderSegment[]
local function file_segments(row)
	return {
		{ text = string.rep(" ", 3 + 2 * row.depth) },
		{ text = UNCHECKED, group = "ChangesCheckbox" },
		{ text = " " },
		{ text = FILE },
		{ text = " " },
		{ text = row.label, group = STATUS_GROUPS[row.status] or "FileTreeFileName" },
	}
end

---@param row ChangesRow
---@return ChangesRenderSegment[]
local function segments_for(row)
	if row.kind == "root" then
		return root_segments(row)
	end
	if row.kind == "directory" then
		return directory_segments(row)
	end
	return file_segments(row)
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
---@param _width integer
---@return nil
function M.draw(buf, rows, _width)
	local rendered = {}
	local lines = {}
	for index, row in ipairs(rows) do
		local segments = segments_for(row)
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
