-- Find Usages geometry keeps the joined frame stable; tune TREE_SHARE and WIDE_MIN_COLUMNS for its split breakpoint.
local M = {}

local TREE_SHARE = 0.45
local WIDE_MIN_COLUMNS = 80
local PREVIEW_HIGHLIGHT = "Normal:MiniPickNormal,FloatBorder:PickerBorder,FloatTitle:MiniPickBorderText,EndOfBuffer:MiniPickNormal"
	.. ",WinBar:MiniPickNormal,WinBarNC:MiniPickNormal"
local TREE_PADDING = "%{%v:relnum ? '%#MiniPickNormal#' : '%#MiniPickMatchCurrent#'%} "
local WIDE_TREE_BORDER = { "╭", "─", "┬", "│", "┴", "─", "├", "│" }
local NARROW_TREE_BORDER = { "╭", "─", "╮", "│", "┤", "─", "├", "│" }
local PREVIEW_BORDER = { "┬", "─", "╮", "│", "┤", "─", "┴", "│" }
-- The tree and preview bottom borders draw the rule above the hints.
local HINT_BORDER = { "", "", "", "│", "╯", "─", "╰", "│" }
local TOGGLE_ON = "●"
local namespace = vim.api.nvim_create_namespace("gleb_references_layout")

---@class gleb.references.Geometry
---@field inner_width integer
---@field body_height integer
---@field tree_width integer
---@field preview_width integer
---@field row integer
---@field col integer

---@class gleb.references.LayoutCallbacks
---@field hint fun(wide: boolean): string
---@field render_tree fun(width?: integer)
---@field update_preview fun()

---@param buf integer
---@param lines string[]
local function set_lines(buf, lines)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
end

--- Without the preview the frame fits the widest row or hint plus one padding cell per side.
---@param state gleb.references.ViewState
---@param hint fun(wide: boolean): string
---@return integer
local function fitted_width(state, hint)
	local widest = vim.fn.strdisplaywidth(hint(false))
	for _, line in ipairs(vim.api.nvim_buf_get_lines(state.tree_buf, 0, -1, false)) do
		widest = math.max(widest, vim.fn.strdisplaywidth(line))
	end
	return widest + 2
end

---@param state gleb.references.ViewState
---@param visible boolean
---@param hint fun(wide: boolean): string
---@return gleb.references.Geometry
local function geometry(state, visible, hint)
	local columns, lines = vim.o.columns, vim.o.lines
	local inner_width, body_height, tree_width
	if visible then
		inner_width = columns - 6
		body_height = lines - 6
		tree_width = math.floor(inner_width * TREE_SHARE)
	else
		inner_width = math.min(fitted_width(state, hint), columns - 6)
		body_height = math.max(1, math.min(#state.visible_nodes, lines - 6))
		tree_width = inner_width
	end
	return {
		inner_width = inner_width,
		body_height = body_height,
		tree_width = tree_width,
		preview_width = inner_width - tree_width - 1,
		row = math.floor((lines - body_height - 4) / 2),
		col = math.floor((columns - inner_width - 2) / 2),
	}
end

---@param state gleb.references.ViewState
---@param size gleb.references.Geometry
---@param visible boolean
---@param hint fun(wide: boolean): string
local function render_hint(state, size, visible, hint)
	local text = hint(visible)
	local padding = string.rep(" ", math.max(size.inner_width - vim.fn.strdisplaywidth(text) - 1, 1))
	local line = padding .. text .. " "
	set_lines(state.hint_buf, { line })
	vim.api.nvim_buf_clear_namespace(state.hint_buf, namespace, 0, -1)
	vim.api.nvim_buf_set_extmark(state.hint_buf, namespace, 0, #padding, {
		end_col = #line,
		hl_group = "PickerHint",
		priority = vim.hl.priorities.syntax,
	})
	local toggle = text:find(TOGGLE_ON, 1, true)
	while toggle do
		local col = #padding + toggle - 1
		vim.api.nvim_buf_set_extmark(state.hint_buf, namespace, 0, col, {
			end_col = col + #TOGGLE_ON,
			hl_group = "PickerToggleOn",
			priority = vim.hl.priorities.user,
		})
		toggle = text:find(TOGGLE_ON, toggle + #TOGGLE_ON, true)
	end
end

---@param state gleb.references.ViewState
local function close_preview(state)
	if state.preview_win and vim.api.nvim_win_is_valid(state.preview_win) then
		vim.api.nvim_win_close(state.preview_win, true)
	end
	state.preview_win = nil
	state.preview_buf = nil
end

---@param state gleb.references.ViewState
---@param size gleb.references.Geometry
local function show_preview(state, size)
	if not state.preview_buf then
		state.preview_buf = vim.api.nvim_create_buf(false, true)
		vim.bo[state.preview_buf].buftype = "nofile"
		vim.bo[state.preview_buf].bufhidden = "wipe"
		vim.bo[state.preview_buf].swapfile = false
		vim.bo[state.preview_buf].modifiable = false
		vim.bo[state.preview_buf].filetype = "gleb-references-preview"
		table.insert(state.buffers, state.preview_buf)
	end
	---@type vim.api.keyset.win_config
	local config = {
		relative = "editor",
		row = size.row,
		col = size.col + size.tree_width + 1,
		width = size.preview_width,
		height = size.body_height,
		border = PREVIEW_BORDER,
		style = "minimal",
		focusable = false,
		zindex = 50,
	}
	if state.preview_win then
		vim.api.nvim_win_set_config(state.preview_win, config)
	else
		state.preview_win = vim.api.nvim_open_win(state.preview_buf, false, config)
		vim.wo[state.preview_win].winhighlight = PREVIEW_HIGHLIGHT
		vim.wo[state.preview_win].cursorline = false
		vim.wo[state.preview_win].number = false
		vim.wo[state.preview_win].signcolumn = "no"
		table.insert(state.windows, state.preview_win)
	end
end

---Apply the joined tree, preview, and hint layout while preserving the selected node.
---@param state gleb.references.ViewState
---@param callbacks gleb.references.LayoutCallbacks
---@return nil
function M.apply(state, callbacks)
	callbacks.render_tree()
	local visible = state.preview_visible == true and vim.o.columns >= WIDE_MIN_COLUMNS
	local size = geometry(state, visible, callbacks.hint)
	vim.api.nvim_win_set_config(state.tree_win, {
		relative = "editor",
		row = size.row,
		col = size.col,
		width = size.tree_width,
		height = size.body_height,
		border = visible and WIDE_TREE_BORDER or NARROW_TREE_BORDER,
		title = string.format(
			" Usages of %s · %d%s ",
			state.title,
			state.tree.count,
			state.classifying and " · classifying" or ""
		),
		title_pos = "left",
		style = "minimal",
		zindex = 50,
	})
	vim.wo[state.tree_win].statuscolumn = TREE_PADDING
	callbacks.render_tree(size.tree_width - 2)

	if visible then
		show_preview(state, size)
	else
		close_preview(state)
	end
	callbacks.update_preview()

	render_hint(state, size, visible, callbacks.hint)
	vim.api.nvim_win_set_config(state.hint_win, {
		relative = "editor",
		row = size.row + size.body_height + 2,
		col = size.col,
		width = size.inner_width,
		height = 1,
		border = HINT_BORDER,
		style = "minimal",
		focusable = false,
		zindex = 51,
	})
end

return M
