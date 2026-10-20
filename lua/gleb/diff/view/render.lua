-- Window-scoped rendering for aligned diff rows.
-- Extmarks tint real lines and insert padding while statuscolumn draws the centre gutter; providers' virtual lines
-- under right lines get blank rows on the left.

local engine = require("gleb.diff.engine")
local providers = require("gleb.diff.view.providers")

local M = {}

---@param view gleb.diff.view.View
---@param side "left"|"right"
---@param line integer
---@return gleb.diff.view.Row?
local function row_at_line(view, side, line)
	for _, row in ipairs(view.layout.rows) do
		if row[side] == line then
			return row
		end
	end
end

---@param text string
---@param group string
---@return string
local function highlighted(text, group)
	return "%#" .. group .. "#" .. text .. "%*"
end

---@param view gleb.diff.view.View
---@param row gleb.diff.view.Row
---@return string
local function row_suffix(view, row)
	if view.committed and row.kind ~= "Moved" then
		return "Committed"
	end
	return assert(row.kind, "diff row requires a kind")
end

---@param row gleb.diff.view.Row
---@param view gleb.diff.view.View
---@return string
local function gutter(view, row)
	if row.fold then
		return highlighted(string.rep("~", 16), "DiffViewFold")
	end
	local kind = row.kind
	local arrow = row.first and "»" or " "
	local arrow_kind = view.committed and kind ~= "Moved" and "Committed" or row.arrow_kind or kind
	local left = row.left and string.format("%3d ", row.left) or "╱╱╱╱"
	local right = row.right and string.format("%3d ", row.right) or "╱╱╱╱"
	local checkbox = not view.committed
			and row.first
			and row.checkbox
			and (type(row.checkbox) == "string" and row.checkbox or "󰄱")
		or " "
	if not kind then
		return highlighted(arrow, "Normal")
			.. highlighted(left, "DiffViewLineNr")
			.. highlighted("     ", "Normal")
			.. highlighted(right, "DiffViewLineNr")
			.. highlighted(checkbox .. " ", "Normal")
	end
	local suffix = row_suffix(view, row)
	local strip = row.move_marker and highlighted(row.move_marker, "DiffViewMovedMarker")
		or highlighted("     ", "DiffView" .. suffix)
	return highlighted(arrow, row.first and ("DiffViewArrow" .. arrow_kind) or "Normal")
		.. highlighted(left, row.left and ("DiffViewGutter" .. suffix) or "DiffViewPadding")
		.. strip
		.. highlighted(right, row.right and ("DiffViewGutter" .. suffix) or "DiffViewPadding")
		.. highlighted(checkbox .. " ", "DiffViewGutter" .. suffix)
end

---@param row gleb.diff.view.Row
---@param view gleb.diff.view.View
---@return table[]
local function padding_gutter(view, row)
	local kind = assert(row.kind, "padding gutter requires a diff row")
	local suffix = "DiffView" .. row_suffix(view, row)
	local gutter_suffix = "DiffViewGutter" .. row_suffix(view, row)
	local arrow_kind = view.committed and kind ~= "Moved" and "Committed" or row.arrow_kind or kind
	local checkbox = not view.committed
			and row.first
			and row.checkbox
			and (type(row.checkbox) == "string" and row.checkbox or "󰄱")
		or nil
	return {
		{ row.first and "»" or " ", row.first and ("DiffViewArrow" .. arrow_kind) or "Normal" },
		{
			row.left and string.format("%3d ", row.left) or "╱╱╱╱",
			row.left and gutter_suffix or "DiffViewPadding",
		},
		{ row.move_marker or "     ", row.move_marker and "DiffViewMovedMarker" or suffix },
		{
			row.right and string.format("%3d ", row.right) or "╱╱╱╱",
			row.right and gutter_suffix or "DiffViewPadding",
		},
		view.committed and { " ", suffix }
			or checkbox and { checkbox, "DiffViewCheckbox" }
			or { "╱", "DiffViewPadding" },
		{ row.right and " " or "╱", row.right and gutter_suffix or "DiffViewPadding" },
	}
end

---@return string
function M.statuscolumn()
	local win = vim.g.statusline_winid
	local view = require("gleb.diff.view").state.by_win[win]
	if not view then
		return ""
	end
	local side = win == view.left_win and "left" or "right"
	local row = row_at_line(view, side, vim.v.lnum)
	if not row then
		return side == "left" and " " or string.rep(" ", 16)
	end
	if side == "left" then
		if row.fold then
			return highlighted("~", "DiffViewFold")
		end
		return highlighted(" ", row.kind and ("DiffView" .. row_suffix(view, row)) or "Normal")
	end
	return gutter(view, row)
end

---@return table
function M.foldtext()
	local view = require("gleb.diff.view").state.by_win[vim.api.nvim_get_current_win()]
	if not view or vim.api.nvim_get_current_win() == view.right_win then
		return {}
	end
	local count = vim.v.foldend - vim.v.foldstart + 1
	return { { "~", "DiffViewFold" }, { " " .. count .. " unchanged lines ", "DiffViewFoldText" } }
end

--- `count` blank rows that stand for a provider's virtual lines on the other side.
---@param count integer
---@return gleb.diff.view.VirtLine[]
local function blank_rows(count)
	local rows = {}
	for index = 1, count do
		rows[index] = { { "", "DiffViewPadding" } }
	end
	return rows
end

---@param view gleb.diff.view.View
---@param side "left"|"right"
---@param rows gleb.diff.view.Row[]
---@param decorations table<integer, gleb.diff.view.VirtLine[]> provider lines by right line
---@param next_line? integer
local function add_padding(view, side, rows, decorations, next_line)
	local buf = side == "left" and view.left_buf or view.right_buf
	local win = side == "left" and view.left_win or view.right_win
	local line_count = vim.api.nvim_buf_line_count(buf)
	local at = next_line and next_line - 1 or math.max(line_count - 1, 0)
	local width = vim.api.nvim_win_get_width(win)
	local contents = {}
	for _, row in ipairs(rows) do
		local content = { { string.rep("╱", width), "DiffViewPadding" } }
		if side == "right" then
			content = padding_gutter(view, row)
			table.insert(content, { string.rep("╱", width - 16), "DiffViewPadding" })
		end
		contents[#contents + 1] = content
		vim.list_extend(contents, blank_rows(row.right and #(decorations[row.right] or {}) or 0))
	end
	vim.api.nvim_buf_set_extmark(buf, view.ns, at, 0, {
		virt_lines = contents,
		virt_lines_above = next_line ~= nil,
		virt_lines_leftcol = true,
	})
end

---@param buf integer
---@param ns integer
---@param row integer
---@param group string
---@param start_col integer
---@param end_col integer
local function add_range(buf, ns, row, group, start_col, end_col)
	vim.api.nvim_buf_set_extmark(buf, ns, row, start_col, {
		end_col = end_col == -1 and 0 or end_col,
		end_row = end_col == -1 and row + 1 or nil,
		hl_eol = end_col == -1,
		hl_group = group,
		priority = 100,
		strict = false,
	})
end

---@param buf integer
---@param ns integer
---@param row integer
---@param kind string
---@param words table[]
local function decorate_line(buf, ns, row, kind, words)
	table.sort(words, function(left, right)
		return left.col_start < right.col_start
	end)
	local col = 0
	for _, word in ipairs(words) do
		if col < word.col_start then
			add_range(buf, ns, row, "DiffView" .. kind, col, word.col_start)
		end
		add_range(
			buf,
			ns,
			row,
			kind == "Committed" and "DiffViewCommittedWord" or "DiffViewWord",
			word.col_start,
			word.col_end
		)
		col = math.max(col, word.col_end)
	end
	add_range(buf, ns, row, "DiffView" .. kind, col, -1)
end

--- Put a provider's virtual lines under right line `row.right`, and as many blank rows under the left line beside it
--- (inside a fold too, for when it opens).
---@param view gleb.diff.view.View
---@param side "left"|"right"
---@param row gleb.diff.view.Row
---@param decorations table<integer, gleb.diff.view.VirtLine[]> provider lines by right line
local function add_decoration(view, side, row, decorations)
	local virt_lines = row.right and decorations[row.right]
	if not virt_lines then
		return
	end
	local buf = side == "left" and view.left_buf or view.right_buf
	vim.api.nvim_buf_set_extmark(buf, view.ns, row[side] - 1, 0, {
		virt_lines = side == "right" and virt_lines or blank_rows(#virt_lines),
	})
end

---@param view gleb.diff.view.View
---@param side "left"|"right"
---@param lines string[]
---@param decorations table<integer, gleb.diff.view.VirtLine[]> provider lines by right line
local function decorate_side(view, side, lines, decorations)
	local buf = side == "left" and view.left_buf or view.right_buf
	local words_by_row = {}
	for _, fragment in ipairs(view.fragments) do
		for _, column in ipairs(engine.inner_columns(fragment, side == "left" and 1 or 2, lines) or {}) do
			if column.col_start < column.col_end then
				words_by_row[column.row] = words_by_row[column.row] or {}
				table.insert(words_by_row[column.row], column)
			end
		end
	end
	local padding = {}
	for _, row in ipairs(view.layout.rows) do
		local line = row[side]
		if line and #padding > 0 then
			add_padding(view, side, padding, decorations, line)
			padding = {}
		end
		if line and row.kind then
			decorate_line(buf, view.ns, line - 1, row_suffix(view, row), words_by_row[line - 1] or {})
		elseif not line and row.change then
			padding[#padding + 1] = row
		end
		if row.fold then
			for offset = 0, row.count - 1 do
				add_decoration(view, side, { left = row.left + offset, right = row.right + offset }, decorations)
			end
		elseif line then
			add_decoration(view, side, row, decorations)
		end
	end
	if #padding > 0 then
		add_padding(view, side, padding, decorations)
	end
end

---@param view gleb.diff.view.View
function M.draw(view)
	if
		not vim.api.nvim_win_is_valid(view.left_win)
		or not vim.api.nvim_win_is_valid(view.right_win)
		or not vim.api.nvim_buf_is_valid(view.left_buf)
		or not vim.api.nvim_buf_is_valid(view.right_buf)
	then
		return
	end
	vim.api.nvim_buf_clear_namespace(view.left_buf, view.ns, 0, -1)
	vim.api.nvim_buf_clear_namespace(view.right_buf, view.ns, 0, -1)
	vim.api.nvim__ns_set(view.ns, { wins = { view.left_win, view.right_win } })
	local decorations = providers.collect(view)
	decorate_side(view, "left", view.left, decorations)
	decorate_side(view, "right", view.right, decorations)
end

return M
