local palette = require("gleb.colors.gruvbox-material.palette")

vim.api.nvim_set_hl(0, "PmenuSel", { fg = "none", bg = palette.background.bg5 }) -- this preserves cmp colors for completion menu

vim.api.nvim_set_hl(0, "CmpItemAbbrDeprecated", { bg = "none", fg = palette.background.bg5 })
vim.api.nvim_set_hl(0, "CmpItemAbbrMatch", { bg = "none", fg = palette.foreground.blue })
vim.api.nvim_set_hl(0, "CmpItemAbbrMatchFuzzy", { bg = "none", fg = palette.foreground.blue })
vim.api.nvim_set_hl(0, "CmpItemKindVariable", { bg = "none", fg = palette.foreground.aqua })
vim.api.nvim_set_hl(0, "CmpItemKindInterface", { bg = "none", fg = palette.foreground.green })
vim.api.nvim_set_hl(0, "CmpItemKindText", { bg = "none", fg = palette.foreground.blue })
vim.api.nvim_set_hl(0, "CmpItemKindFunction", { bg = "none", fg = palette.foreground.blue })
vim.api.nvim_set_hl(0, "CmpItemKindMethod", { bg = "none", fg = palette.foreground.blue })
vim.api.nvim_set_hl(0, "CmpItemKindKeyword", { bg = "none", fg = palette.foreground.red })
vim.api.nvim_set_hl(0, "CmpItemKindProperty", { bg = "none", fg = palette.foreground.aqua })
vim.api.nvim_set_hl(0, "CmpItemKindField", { bg = "none", fg = palette.foreground.aqua })
vim.api.nvim_set_hl(0, "CmpItemKindUnit", { bg = "none", fg = palette.foreground.purple })
vim.api.nvim_set_hl(0, "CmpItemKindConstant", { bg = "none", fg = palette.foreground.purple })
vim.api.nvim_set_hl(0, "CmpItemKindEnum", { bg = "none", fg = palette.foreground.purple })
vim.api.nvim_set_hl(0, "CmpItemKindClass", { bg = "none", fg = palette.foreground.green })
vim.api.nvim_set_hl(0, "CmpItemKindStruct", { bg = "none", fg = palette.foreground.green })
vim.api.nvim_set_hl(0, "CmpItemKindCopilot", { bg = "none", fg = palette.foreground.red })
