local palette = require("gleb.colors.gruvbox-material.palette")
local bg = palette.background

vim.g.gitblame_highlight_group = "TSKeyword"

-- diff colors
vim.api.nvim_set_hl(0, "DiffAdd", { bg = bg.bg_visual_green })
vim.api.nvim_set_hl(0, "DiffChange", { bg = bg.bg_visual_blue })
vim.api.nvim_set_hl(0, "DiffDelete", { bg = bg.bg_visual_red })
vim.api.nvim_set_hl(0, "DiffText", { bg = bg.bg_visual_blue })
