-- Pull-request UI highlights derive from the active gruvbox-material and statusline palettes.

local M = {}

local palette = require("gleb.colors.gruvbox-material.palette")
local color_util = require("gleb.colors.gruvbox-material.util")

local function apply()
	local foreground = palette.foreground
	local background = palette.background
	local bar = require("gleb.statusline.palette").bar
	local confirm_background = color_util.blend(foreground.yellow, background.bg0, 0.8)
	vim.api.nvim_set_hl(0, "PrPeek", { fg = foreground.fg0 })
	vim.api.nvim_set_hl(0, "PrPeekAuthor", { fg = foreground.aqua, bold = true })
	vim.api.nvim_set_hl(0, "PrPeekIcon", { fg = foreground.yellow })
	vim.api.nvim_set_hl(0, "PrPeekMeta", { fg = foreground.grey1 })
	vim.api.nvim_set_hl(0, "PrThreadResolved", { fg = foreground.grey0, italic = true })
	vim.api.nvim_set_hl(0, "PrThreadOutdated", { fg = foreground.orange })
	vim.api.nvim_set_hl(0, "ChangesTabComments", { fg = background.bg0, bg = foreground.yellow, bold = true })
	vim.api.nvim_set_hl(0, "PrStatuslineNumber", { fg = foreground.purple, bg = bar })
	vim.api.nvim_set_hl(0, "PrStatuslineThreads", { fg = foreground.yellow, bg = bar })
	vim.api.nvim_set_hl(0, "PrConfirm", { fg = foreground.yellow, bg = confirm_background, bold = true })
	vim.api.nvim_set_hl(0, "PrConfirmHint", { fg = foreground.fg1, bg = confirm_background })
	vim.api.nvim_set_hl(0, "PrReplyPlaceholder", { fg = foreground.grey0, italic = true })
end

---@return nil
function M.setup()
	apply()
	local group = vim.api.nvim_create_augroup("gleb_pr_highlights", { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = apply })
end

return M
