local status_ok, bufferline = pcall(require, "bufferline")
if not status_ok then
	return
end

-- share the statusline's derived palette so the top (bufferline) and bottom
-- (lualine) lines are the same color and blend in together
local c = require("gleb.statusline.palette")

local function buferFilter(buf_number)
	-- filter out filetypes you don't want to see
	if vim.bo[buf_number].filetype == "dap-repl" then
		return false
	end

	return true
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
		-- buffer_close_icon = '',
		modified_icon = "●",
		close_icon = "",
		-- close_icon = '',
		left_trunc_marker = "",
		right_trunc_marker = "",
		--- name_formatter can be used to change the buffer's label in the bufferline.
		--- Please note some names can/will break the
		--- bufferline so use this at your discretion knowing that it has
		--- some limitations that will *NOT* be fixed.
		-- name_formatter = function(buf)  -- buf contains a "name", "path" and "bufnr"
		--   -- remove extension from markdown files for example
		--   if buf.name:match('%.md') then
		--     return vim.fn.fnamemodify(buf.name, ':t:r')
		--   end
		-- end,
		max_name_length = 30,
		max_prefix_length = 30, -- prefix used when a buffer is de-duplicated
		tab_size = 21,
		diagnostics = false, -- | "nvim_lsp" | "coc",
		diagnostics_update_in_insert = false,
		-- diagnostics_indicator = function(count, level, diagnostics_dict, context)
		--   return "("..count..")"
		-- end,
		-- NOTE: this will be called a lot so don't do any heavy processing here
		custom_filter = buferFilter,
		offsets = { { filetype = "NvimTree", text = "", padding = 1 } },
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
		-- sort_by = 'id' | 'extension' | 'relative_directory' | 'directory' | 'tabs' | function(buffer_a, buffer_b)
		--   -- add custom logic
		--   return buffer_a.modified > buffer_b.modified
		-- end
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
