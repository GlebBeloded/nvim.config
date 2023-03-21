local palette = require("gleb.colors.gruvbox-material.palette")

local fg = palette.foreground
local bg = palette.background

-- remove background colors from lsp diagnotics
vim.api.nvim_set_hl(0, "DiagnosticVirtualTextError", { fg = bg.bg_visual_red })
vim.api.nvim_set_hl(0, "DiagnosticVirtualTextHint", { fg = bg.bg_visual_green })
vim.api.nvim_set_hl(0, "DiagnosticVirtualTextInfo", { fg = bg.bg_visual_blue })
vim.api.nvim_set_hl(0, "DiagnosticVirtualTextWarn", { fg = bg.bg_visual_yellow })

-- set lighbulb color to yellow
vim.cmd([[highlight LightBulbFloatWin guifg=#e0af68 ]])
vim.cmd([[highlight LightBulbVirtualText guifg=#e0af68 ]])

vim.api.nvim_set_hl(0, "SpellBad", { cterm = { undercurl = true }, fg = palette.foreground.red })
vim.api.nvim_set_hl(0, "SpellCap", { cterm = { undercurl = true }, fg = palette.foreground.yellow })
vim.api.nvim_set_hl(0, "SpellLocal", { cterm = { undercurl = true }, fg = palette.foreground.blue })
vim.api.nvim_set_hl(0, "SpellRare", { cterm = { undercurl = true }, fg = palette.foreground.purple })
