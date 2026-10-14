-- Responsive picker policy: keep breakpoint choices pure and evaluate window geometry on every refresh.

local M = {}

local FULL_MIN = 72
local COMPACT_MIN = 48
local SHORT_LINES = 15
local MAX_WIDTH = 70
local NORMAL_HEIGHT = 6

---@alias gleb.picker.LayoutKind "full"|"compact"|"narrow"

---@class gleb.picker.Layout
---@field kind gleb.picker.LayoutKind
---@field show_secondary boolean
---@field show_category boolean
---@field show_glyph boolean
---@field hint? string

---@class gleb.picker.WindowConfig
---@field relative "editor"
---@field anchor "NW"
---@field row integer
---@field col integer
---@field width integer
---@field height integer
---@field border "rounded"

---@param columns integer
---@return gleb.picker.Layout
local function layout_for(columns)
	if columns >= FULL_MIN then
		return {
			kind = "full",
			show_secondary = true,
			show_category = true,
			show_glyph = true,
			hint = "Open ↩ · Split ⌃S · Vsplit ⌃V",
		}
	end

	if columns >= COMPACT_MIN then
		return {
			kind = "compact",
			show_secondary = true,
			show_category = false,
			show_glyph = false,
			hint = "↩ · ⌃S · ⌃V",
		}
	end

	return {
		kind = "narrow",
		show_secondary = false,
		show_category = false,
		show_glyph = false,
	}
end

---@param columns? integer
---@return gleb.picker.Layout
function M.current(columns)
	return layout_for(columns or vim.o.columns)
end

---@param columns? integer
---@return gleb.picker.RowRenderOpts
function M.row_options(columns)
	local layout = M.current(columns)
	return {
		show_secondary = layout.show_secondary,
		show_category = layout.show_category,
		show_glyph = layout.show_glyph,
	}
end

---@param columns? integer
---@return string?
function M.hint(columns)
	return M.current(columns).hint
end

---@return gleb.picker.WindowConfig
function M.window_config()
	local columns, lines = vim.o.columns, vim.o.lines
	local width = math.max(math.min(MAX_WIDTH, columns - 2), 1)
	local height = lines < SHORT_LINES and math.max(lines - 2, 1) or NORMAL_HEIGHT

	return {
		relative = "editor",
		anchor = "NW",
		row = math.max(math.floor((lines - height - 2) / 2), 0),
		col = math.max(math.floor((columns - width - 2) / 2), 0),
		width = width,
		height = height,
		border = "rounded",
	}
end

return M
