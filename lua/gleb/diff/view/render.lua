-- Window-scoped rendering for aligned diff rows.
-- Extmarks tint real lines and insert padding while statuscolumn draws the centre gutter.

local engine = require("gleb.diff.engine")
local layout = require("gleb.diff.view.layout")

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
	return "%#" .. group .. "#" .. text
end

---@param row gleb.diff.view.Row
---@return string
local function gutter(row)
	if row.fold then
		return highlighted(string.rep("~", 16), "DiffViewFold")
	end
	local kind = row.kind
	local arrow = row.first and "»" or " "
	local left = row.left and string.format("%3d ", row.left) or "╱╱╱╱"
	local right = row.right and string.format("%3d ", row.right) or "╱╱╱╱"
	local checkbox = row.first and row.checkbox and "☐" or " "
	if not kind then
		return arrow
			.. highlighted(left, "DiffViewLineNr")
			.. "     "
			.. highlighted(right, "DiffViewLineNr")
			.. checkbox
			.. " "
	end
	local suffix = kind
	return highlighted(arrow, row.first and ("DiffViewArrow" .. suffix) or ("DiffViewGutter" .. suffix))
		.. highlighted(left, row.left and ("DiffViewGutter" .. suffix) or "DiffViewPadding")
		.. highlighted("     ", "DiffView" .. suffix)
		.. highlighted(right, row.right and ("DiffViewGutter" .. suffix) or "DiffViewPadding")
		.. highlighted(checkbox .. " ", "DiffViewGutter" .. suffix)
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
		return highlighted(" ", row.kind and ("DiffView" .. row.kind) or "Normal")
	end
	return gutter(row)
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

---@param view gleb.diff.view.View
---@param side "left"|"right"
---@param row gleb.diff.view.Row
local function add_padding(view, side, row)
	local buf = side == "left" and view.left_buf or view.right_buf
	local next_line
	local found = false
	for _, candidate in ipairs(view.layout.rows) do
		if candidate == row then
			found = true
		elseif found and candidate[side] then
			next_line = candidate[side]
			break
		end
	end
	local line_count = vim.api.nvim_buf_line_count(buf)
	local at = next_line and next_line - 1 or math.max(line_count - 1, 0)
	local content = side == "right" and { { layout.gutter(row), "Normal" }, { "╱", "DiffViewPadding" } }
		or { { "╱", "DiffViewPadding" } }
	vim.api.nvim_buf_set_extmark(buf, view.ns, at, 0, {
		virt_lines = { content },
		virt_lines_above = next_line ~= nil,
		virt_lines_leftcol = true,
	})
end

---@param view gleb.diff.view.View
---@param side "left"|"right"
---@param lines string[]
local function decorate_side(view, side, lines)
	local buf = side == "left" and view.left_buf or view.right_buf
	for _, row in ipairs(view.layout.rows) do
		local line = row[side]
		if line and row.kind then
			vim.api.nvim_buf_set_extmark(buf, view.ns, line - 1, 0, {
				line_hl_group = "DiffView" .. row.kind,
				priority = 100,
			})
		elseif not line and row.change then
			add_padding(view, side, row)
		end
	end
	for _, fragment in ipairs(view.fragments) do
		for _, column in ipairs(engine.inner_columns(fragment, side == "left" and 1 or 2, lines) or {}) do
			if column.col_start < column.col_end then
				vim.api.nvim_buf_set_extmark(buf, view.ns, column.row, column.col_start, {
					end_col = column.col_end,
					hl_group = "DiffViewWord",
					priority = 110,
				})
			end
		end
	end
end

---@param view gleb.diff.view.View
function M.draw(view)
	vim.api.nvim_buf_clear_namespace(view.left_buf, view.ns, 0, -1)
	vim.api.nvim_buf_clear_namespace(view.right_buf, view.ns, 0, -1)
	vim.api.nvim__ns_set(view.ns, { wins = { view.left_win, view.right_win } })
	decorate_side(view, "left", view.left)
	decorate_side(view, "right", view.right)
end

return M
