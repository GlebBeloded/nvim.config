local highlights = require("neo-tree.ui.highlights")

local palette = require("gleb.colors.gruvbox-material.palette")
local bg = palette.background
local fg = palette.foreground

vim.g.gitblame_highlight_group = "TSKeyword"

-- diff colors
vim.api.nvim_set_hl(0, "DiffAdd", { bg = bg.bg_visual_green })
vim.api.nvim_set_hl(0, "DiffChange", { bg = bg.bg_visual_blue })
vim.api.nvim_set_hl(0, "DiffDelete", { bg = bg.bg_visual_red })
vim.api.nvim_set_hl(0, "DiffText", { bg = bg.bg_visual_blue })

-- Custom git status colors for filenames (gruvbox-material palette)
vim.api.nvim_set_hl(0, highlights.GIT_ADDED, { fg = fg.green }) -- green for new files
vim.api.nvim_set_hl(0, highlights.GIT_MODIFIED, { fg = fg.blue }) -- blue for modified
vim.api.nvim_set_hl(0, highlights.GIT_DELETED, { fg = fg.red }) -- red for deleted
vim.api.nvim_set_hl(0, highlights.GIT_UNTRACKED, { fg = fg.red }) -- red for untracked
vim.api.nvim_set_hl(0, highlights.GIT_CONFLICT, { fg = fg.yellow }) -- yellow for conflicts
-- vim.api.nvim_set_hl(0, highlights.GIT_STAGED, { fg = "#a9b665" }) -- green for staged
