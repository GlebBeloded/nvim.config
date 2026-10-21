-- Diff-view colours derived from the active gruvbox-material palette.
-- Reapplying on ColorScheme keeps the owned UI coherent after a theme reload.

local palette = require("gleb.colors.gruvbox-material.palette")
local util = require("gleb.colors.gruvbox-material.util")

local M = {}

---@return nil
function M.setup()
	local bg = palette.background
	local fg = palette.foreground
	local kinds = {
		Add = { colour = fg.green, ratio = 0.72 },
		Change = { colour = fg.blue, ratio = 0.72 },
		Delete = { colour = fg.red, ratio = 0.74 },
	}
	for kind, spec in pairs(kinds) do
		local tint = util.blend(spec.colour, bg.bg0, spec.ratio)
		vim.api.nvim_set_hl(0, "DiffView" .. kind, { bg = tint })
		vim.api.nvim_set_hl(0, "DiffViewGutter" .. kind, { fg = fg.grey1, bg = tint })
		vim.api.nvim_set_hl(0, "DiffViewArrow" .. kind, { fg = spec.colour, bg = tint })
	end
	local moved = util.blend(fg.aqua, bg.bg0, 0.72)
	vim.api.nvim_set_hl(0, "DiffViewMoved", { bg = moved })
	vim.api.nvim_set_hl(0, "DiffViewGutterMoved", { fg = fg.grey1, bg = moved })
	vim.api.nvim_set_hl(0, "DiffViewMovedMarker", { fg = fg.aqua, bg = moved })
	vim.api.nvim_set_hl(0, "DiffViewWord", { bg = util.blend(fg.blue, bg.bg0, 0.5) })
	vim.api.nvim_set_hl(0, "DiffViewLineNr", { fg = fg.grey1 })
	vim.api.nvim_set_hl(0, "DiffViewCheckbox", { fg = fg.grey1 })
	vim.api.nvim_set_hl(0, "DiffViewPadding", { fg = bg.bg3 })
	vim.api.nvim_set_hl(0, "DiffViewFold", { fg = bg.bg5 })
	vim.api.nvim_set_hl(0, "DiffViewFoldText", { fg = fg.grey1 })
	vim.api.nvim_set_hl(0, "DiffViewHeader", { fg = fg.grey1, bg = bg.bg0 })
end

M.setup()
vim.api.nvim_create_autocmd("ColorScheme", {
	group = vim.api.nvim_create_augroup("gleb_diff_view_highlights", { clear = true }),
	callback = M.setup,
})

return M
