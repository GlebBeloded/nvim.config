-- Changes highlights use the shared theme palette and survive colorscheme reloads.

local M = {}

local palette = require("gleb.colors.gruvbox-material.palette")

local function apply_highlights()
	local background = palette.background
	local foreground = palette.foreground
	vim.api.nvim_set_hl(0, "ChangesTabLocal", { fg = background.bg0, bg = foreground.blue, bold = true })
	vim.api.nvim_set_hl(0, "ChangesTabBranch", { fg = background.bg0, bg = foreground.purple, bold = true })
	vim.api.nvim_set_hl(0, "ChangesTabComments", { fg = background.bg0, bg = foreground.yellow, bold = true })
	vim.api.nvim_set_hl(0, "ChangesTabInactive", { fg = foreground.grey1, bg = background.bg1 })
	vim.api.nvim_set_hl(0, "ChangesBranchHeader", { fg = foreground.purple, bold = true })
	vim.api.nvim_set_hl(0, "ChangesCommittedFile", { fg = foreground.purple })
	vim.api.nvim_set_hl(0, "ChangesCommitIcon", { fg = foreground.purple })
	vim.api.nvim_set_hl(0, "ChangesCommitHash", { fg = foreground.yellow })
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
