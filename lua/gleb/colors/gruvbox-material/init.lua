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
