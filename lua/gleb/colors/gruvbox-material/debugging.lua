local colors = require("gleb.colors.gruvbox-material.palette")

vim.cmd([[ highlight DapStopped guibg= ]] .. colors.background.bg_visual_yellow)
