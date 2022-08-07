local colorscheme = "tokyonight"

vim.g.tokyonight_transparent = true

pcall(vim.cmd, "colorscheme " .. colorscheme)

-- remove background colors from lsp diagnotics
vim.cmd[[highlight   DiagnosticVirtualTextError              guifg=#db4b4b guibg=none]]
vim.cmd[[highlight   DiagnosticVirtualTextHint               guifg=#1abc9c guibg=none]]
vim.cmd[[highlight   DiagnosticVirtualTextInfo               guifg=#0db9d7 guibg=none]]
vim.cmd[[highlight   DiagnosticVirtualTextWarn               guifg=#e0af68 guibg=none]]

-- set lighbulb color to yellow
vim.cmd[[highlight LightBulbFloatWin guifg=#e0af68 ]]
vim.cmd[[highlight LightBulbVirtualText guifg=#e0af68 ]]
