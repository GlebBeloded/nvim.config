local palette = require("gleb.colors.gruvbox-material.palette")

-- remove background colors from lsp diagnotics
vim.api.nvim_set_hl(0, "DiagnosticVirtualTextError", { fg = palette.background.bg_visual_red }) -- function args
vim.api.nvim_set_hl(0, "DiagnosticVirtualTextHint", { fg = palette.background.bg_visual_green }) -- function args
vim.api.nvim_set_hl(0, "DiagnosticVirtualTextInfo", { fg = palette.background.bg_visual_blue }) -- function args
vim.api.nvim_set_hl(0, "DiagnosticVirtualTextWarn", { fg = palette.background.bg_visual_yellow }) -- function args

-- set lighbulb color to yellow
vim.cmd([[highlight LightBulbFloatWin guifg=#e0af68 ]])
vim.cmd([[highlight LightBulbVirtualText guifg=#e0af68 ]])
