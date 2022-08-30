local colorscheme = "gruvbox-material"

-- for dark theme
-- should be called before colorscheme
vim.cmd([[ set background=dark ]])

pcall(vim.cmd, "colorscheme " .. colorscheme)

require("gleb.colors.gruvbox-material.tree-sitter")
require("gleb.colors.gruvbox-material.lsp")
require("gleb.colors.gruvbox-material.cmp")
