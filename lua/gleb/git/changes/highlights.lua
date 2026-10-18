-- Changes highlights use the shared theme palette and survive colorscheme reloads.

local M = {}

local palette = require("gleb.colors.gruvbox-material.palette")

local function apply_highlights()
	local foreground = palette.foreground
	vim.api.nvim_set_hl(0, "ChangesRoot", { fg = foreground.fg1, bold = true })
	vim.api.nvim_set_hl(0, "ChangesCount", { fg = foreground.grey1 })
	vim.api.nvim_set_hl(0, "ChangesCheckbox", { fg = foreground.grey1 })
	vim.api.nvim_set_hl(0, "ChangesStatAdded", { fg = foreground.green })
	vim.api.nvim_set_hl(0, "ChangesStatRemoved", { fg = foreground.red })
end

--- Define Changes highlights and restore them after colorscheme changes.
---@return nil
function M.setup()
	apply_highlights()
	local group = vim.api.nvim_create_augroup("gleb_changes_highlights", { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = apply_highlights })
end

return M
