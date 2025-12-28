local colorscheme = "gruvbox-material"

-- for dark theme
-- should be called before colorscheme
vim.cmd([[ set background=dark ]])

pcall(vim.cmd, "colorscheme " .. colorscheme)

require("gleb.colors.gruvbox-material.tree-sitter")
require("gleb.colors.gruvbox-material.lsp")
require("gleb.colors.gruvbox-material.cmp")
require("gleb.colors.gruvbox-material.git")
require("gleb.colors.gruvbox-material.debugging")

-- make all error messages look the same
vim.api.nvim_set_hl(0, "NvimInternalError", { link = "error" })
vim.api.nvim_set_hl(0, "RedrawDebugRecompose", { link = "error" })
vim.api.nvim_set_hl(0, "MiniTrailSpace", { link = "error" })
vim.api.nvim_set_hl(0, "MiniSurround", { link = "error" })

-- Neo-tree: same background as buffer
local palette = require("gleb.colors.gruvbox-material.palette")
vim.api.nvim_set_hl(0, "NeoTreeNormal", { bg = palette.background.bg0 })
vim.api.nvim_set_hl(0, "NeoTreeNormalNC", { bg = palette.background.bg0 })
vim.api.nvim_set_hl(0, "NeoTreeEndOfBuffer", { bg = palette.background.bg0, fg = palette.background.bg0 })

-- Thicker window separator
vim.api.nvim_set_hl(0, "WinSeparator", { fg = palette.background.bg3 })
vim.opt.fillchars:append({
	vert = "┃",
	horiz = "━",
	verthoriz = "╋",
	horizup = "┻",
	horizdown = "┳",
	vertleft = "┫",
	vertright = "┣",
})
