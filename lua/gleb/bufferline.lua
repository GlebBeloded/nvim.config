local status_ok, bufferline = pcall(require, "bufferline")
if not status_ok then
	return
end

-- share the statusline's derived palette so the top (bufferline) and bottom
-- (lualine) lines are the same color and blend in together
local c = require("gleb.statusline.palette")
local bufferline_config = require("bufferline.config")

local REGULAR_TAB_SIZE = 21

---@return boolean
local function changes_panel_open()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "gleb-changes" then
			return true
		end
	end
	return false
end

-- Over the changes panel the tab is compact and drawn as selected (design.md "Proposed — tabline over the
-- changes panel"); the panel's buffer is unlisted, so the editor's buffer is only `visible` while it has focus.
-- Called from the filter, which bufferline runs on every render before drawing.
---@return nil
local function update_tab_layout()
	local config = bufferline_config.get()
	local compact = changes_panel_open()
	config.options.tab_size = compact and 1 or REGULAR_TAB_SIZE
	config.options.enforce_regular_tabs = not compact
	config.options.show_buffer_close_icons = compact
	config.options.buffer_close_icon = compact and " " or ""
	config.highlights.buffer_visible.hl_group = compact and "BufferLineBufferSelected" or "BufferLineBufferVisible"
	config.highlights.indicator_visible.hl_group = compact and "BufferLineBufferSelected"
		or "BufferLineIndicatorVisible"
	config.highlights.close_button_visible.hl_group = compact and "BufferLineBufferSelected"
		or "BufferLineCloseButtonVisible"
end

---@param buf_number integer
---@return boolean
local function buffer_filter(buf_number)
	update_tab_layout()
	-- filter out filetypes you don't want to see
	if vim.bo[buf_number].filetype == "dap-repl" then
		return false
	end

	return true
end

-- The compact tab's icon padding takes the tab's colour, not the icon's, and its right edge cell the fill's.
---@param tabline string
---@return string
local function style_visible_icon_spacing(tabline)
	if not changes_panel_open() then
		return tabline
	end
	tabline = tabline:gsub("(%%#BufferLineDevIcon[^#]+Inactive#[^ ]+)( )(%%#BufferLineBufferSelected#)", "%1%3%2%3")
	return (
		tabline:gsub(
			"(%%X) (%%%d+@v:lua%.___bufferline_private%.handle_click@%%#BufferLineFill#%%=)$",
			"%1%%#BufferLineFill# %2"
		)
	)
end

bufferline.setup({
	options = {
		numbers = "none", -- | "ordinal" | "buffer_id" | "both" | function({ ordinal, id, lower, raise }): string,
		close_command = "Bdelete! %d", -- can be a string | function, see "Mouse actions"
		right_mouse_command = "Bdelete! %d", -- can be a string | function, see "Mouse actions"
		left_mouse_command = "buffer %d", -- can be a string | function, see "Mouse actions"
		middle_mouse_command = nil, -- can be a string | function, see "Mouse actions"
		-- NOTE: this plugin is designed with this icon in mind, and so changing this is NOT recommended, this is intended
		-- as an escape hatch for people who cannot bear it for whatever reason
		indicator = { icon = "▎", style = "icon" },
		buffer_close_icon = "",
		modified_icon = "●",
		close_icon = "",
		left_trunc_marker = "",
		right_trunc_marker = "",
		max_name_length = 30,
		max_prefix_length = 30, -- prefix used when a buffer is de-duplicated
		tab_size = REGULAR_TAB_SIZE,
		diagnostics = false, -- | "nvim_lsp" | "coc",
		diagnostics_update_in_insert = false,
		-- NOTE: this will be called a lot so don't do any heavy processing here
		custom_filter = buffer_filter,
		offsets = {
			{ filetype = "gleb-file-tree", text = "", padding = 1, highlight = "FileTreeNormal" },
			{ filetype = "gleb-changes", text = "", padding = 1, highlight = "FileTreeNormal" },
		},
		show_buffer_icons = true,
		show_buffer_close_icons = false,
		show_close_icon = false,
		show_tab_indicators = true,
		persist_buffer_sort = true, -- whether or not custom sorted buffers should persist
		-- can also be a table containing 2 custom separators
		-- [focused and unfocused]. eg: { '|', '|' }
		separator_style = "thin", -- | "thick" | "thin" | { 'any', 'any' },
		enforce_regular_tabs = true,
		always_show_bufferline = true,
	},
	-- match the statusline: bar fill everywhere, active buffer faintly lifted
	highlights = {
		fill = { bg = c.bar },
		background = { fg = c.muted, bg = c.bar },
		buffer_visible = { fg = c.text, bg = c.bar },
		buffer_selected = { fg = c.text_hi, bg = c.bar_sel, bold = true, italic = false },
		duplicate = { fg = c.muted, bg = c.bar },
		duplicate_visible = { fg = c.muted, bg = c.bar },
		duplicate_selected = { fg = c.text, bg = c.bar_sel },
		separator = { fg = c.bar, bg = c.bar },
		separator_visible = { fg = c.bar, bg = c.bar },
		separator_selected = { fg = c.bar, bg = c.bar_sel },
		indicator_selected = { fg = c.mode.normal, bg = c.bar_sel },
		modified = { fg = c.mode.normal, bg = c.bar },
		modified_visible = { fg = c.mode.normal, bg = c.bar },
		modified_selected = { fg = c.mode.normal, bg = c.bar_sel },
		close_button = { fg = c.muted, bg = c.bar },
		close_button_visible = { fg = c.muted, bg = c.bar },
		close_button_selected = { fg = c.err, bg = c.bar_sel },
	},
})

-- 'tabline' calls this global on every redraw; bufferline defines it once when its module loads.
local render_bufferline = _G.nvim_bufferline
---@return string, bufferline.Segment[][]
_G.nvim_bufferline = function()
	local tabline, components = render_bufferline()
	return style_visible_icon_spacing(tabline), components
end
