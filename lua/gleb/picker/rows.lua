-- Picker row anatomy: render structured items directly into mini.pick's result buffer.
-- Field visibility is explicit so responsive layouts can remove metadata without changing sources.

local M = {}

local namespace = vim.api.nvim_create_namespace("gleb_picker_rows")
local layout = require("gleb.picker.layout")

---@class gleb.picker.Row
---@field text string
---@field secondary? string
---@field category? string
---@field glyph? boolean
---@field dim? boolean
---@field section? boolean

---@class gleb.picker.RowRenderOpts
---@field show_secondary? boolean
---@field show_category? boolean
---@field show_glyph? boolean
---@field padding? integer
---@field selected? integer
---@field selected_metadata? boolean

---@class gleb.picker.RowHighlight
---@field col integer
---@field end_col integer
---@field group string

---@class gleb.picker.RenderedRow
---@field text string
---@field highlights gleb.picker.RowHighlight[]

---@param text string
---@return integer
local function display_width(text)
	return vim.fn.strdisplaywidth(text)
end

---@param text string
---@param width integer
---@return string
local function truncate(text, width)
	local characters = vim.fn.strchars(text)
	while characters > 0 and display_width(text) > width do
		characters = characters - 1
		text = vim.fn.strcharpart(text, 0, characters)
	end
	return text
end

---@param item gleb.picker.Row
---@param width integer
---@return gleb.picker.RenderedRow
local function render_section(item, width)
	local remaining = math.max(width - display_width(item.text) - 1, 0)
	local suffix = remaining > 0 and (" " .. string.rep("─", remaining)) or ""
	local text = item.text .. suffix
	local highlights = { { col = 0, end_col = #item.text, group = "PickerSectionLabel" } }
	if suffix ~= "" then
		table.insert(highlights, { col = #item.text + 1, end_col = #text, group = "PickerSectionRule" })
	end

	return {
		text = text,
		highlights = highlights,
	}
end

---@param item gleb.picker.Row
---@param width integer
---@param opts gleb.picker.RowRenderOpts
---@param _selected boolean
---@return gleb.picker.RenderedRow
local function render_item(item, width, opts, _selected)
	local left = item.text
	local highlights = {}

	if item.dim then
		table.insert(highlights, { col = 0, end_col = #left, group = "Comment" })
	end

	if opts.show_secondary and item.secondary then
		local start_col = #left + 2
		left = left .. "  " .. item.secondary
		table.insert(highlights, { col = start_col, end_col = #left, group = "PickerSecondary" })
	end

	local right = ""
	local glyph = item.glyph
	if not opts.show_glyph then
		glyph = nil
	end
	if glyph ~= nil then
		right = glyph and "●" or "○"
	end
	if opts.show_category and item.category then
		right = right == "" and item.category or (right .. " " .. item.category)
	end

	if right == "" then
		return { text = left, highlights = highlights }
	end

	local padding = math.max(width - display_width(left) - display_width(right), 1)
	local right_col = #left + padding
	local text = left .. string.rep(" ", padding) .. right

	if glyph ~= nil then
		table.insert(highlights, {
			col = right_col,
			end_col = right_col + #"●",
			group = glyph and "PickerToggleOn" or "PickerToggleOff",
		})
	end
	if opts.show_category and item.category then
		local category_col = #text - #item.category
		local separator_col = item.category:find(" | ", 1, true)
		if separator_col then
			local separator_start = category_col + separator_col - 1
			table.insert(highlights, { col = category_col, end_col = separator_start, group = "PickerCategory" })
			table.insert(highlights, {
				col = separator_start,
				end_col = separator_start + #" | ",
				group = "PickerCategorySeparator",
			})
			table.insert(highlights, {
				col = separator_start + #" | ",
				end_col = #text,
				group = "PickerCategory",
			})
		else
			table.insert(highlights, { col = category_col, end_col = #text, group = "PickerCategory" })
		end
	end

	return { text = text, highlights = highlights }
end

---@param buf integer
---@param items gleb.picker.Row[]
---@param width integer
---@param opts? gleb.picker.RowRenderOpts
---@return nil
function M.render(buf, items, width, opts)
	opts = vim.tbl_extend("keep", opts or {}, {
		show_secondary = true,
		show_category = true,
		show_glyph = true,
		padding = 0,
	})
	local padding = opts.padding or 0
	local content_width = math.max(width - 2 * padding, 1)

	local rendered = {}
	local lines = {}
	for index, item in ipairs(items) do
		local selected = opts.selected == index
		local row = item.section and render_section(item, content_width)
			or render_item(item, content_width, opts, selected)
		row.text = string.rep(" ", padding) .. truncate(row.text, content_width)
		row.highlights = vim.tbl_filter(function(highlight)
			highlight.col = highlight.col + padding
			highlight.end_col = math.min(highlight.end_col + padding, #row.text)
			return highlight.col < highlight.end_col
		end, row.highlights)
		rendered[index] = row
		lines[index] = row.text
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	for row_index, row in ipairs(rendered) do
		for _, highlight in ipairs(row.highlights) do
			vim.api.nvim_buf_set_extmark(buf, namespace, row_index - 1, highlight.col, {
				end_col = highlight.end_col,
				hl_group = highlight.group,
			})
		end
	end
end

---@param buf integer
---@param items gleb.picker.Row[]
---@param _query string[]
---@return nil
function M.show(buf, items, _query)
	local win = vim.fn.bufwinid(buf)
	local width = win == -1 and vim.o.columns or vim.api.nvim_win_get_width(win)
	M.render(buf, items, width, layout.row_options())
end

return M
