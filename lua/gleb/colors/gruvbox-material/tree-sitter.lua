local palette = require("gleb.colors.gruvbox-material.palette")

-- packages
vim.api.nvim_set_hl(0, "TSNamespace", { fg = palette.background.bg5 }) -- package name
-- variables and fields
vim.api.nvim_set_hl(0, "TSParameter", { fg = palette.foreground.fg0 }) -- function args
vim.api.nvim_set_hl(0, "TSVariable", { fg = palette.foreground.fg1 }) -- variables
vim.api.nvim_set_hl(0, "TSField", { fg = palette.foreground.fg1 }) -- struct fields
vim.api.nvim_set_hl(0, "TSProperty", { fg = palette.foreground.aqua }) -- sturct.field field color
-- functions
vim.api.nvim_set_hl(0, "TSMethod", { fg = palette.foreground.blue }) -- methods
vim.api.nvim_set_hl(0, "TSMethodCall", { fg = palette.foreground.blue }) -- calling methods
vim.api.nvim_set_hl(0, "TSFuncBuiltin", { fg = palette.foreground.blue }) -- built in functions
vim.api.nvim_set_hl(0, "TSFunction", { fg = palette.foreground.blue }) -- functions
-- types
vim.api.nvim_set_hl(0, "TSType", { fg = palette.foreground.green }) -- type name
vim.api.nvim_set_hl(0, "TSTypeBuiltin", { fg = palette.foreground.green }) -- built in types(int,any)
-- builtins
vim.api.nvim_set_hl(0, "TSConstBuiltin", { fg = palette.foreground.orange }) -- nil, const
vim.api.nvim_set_hl(0, "TSOperator", { fg = palette.foreground.red }) -- operators
vim.api.nvim_set_hl(0, "TSKeyword", { fg = palette.foreground.red }) -- keywords
vim.api.nvim_set_hl(0, "TSKeywordReturn", { fg = palette.foreground.red }) -- return keyword
vim.api.nvim_set_hl(0, "TSPunctDelimiter", { fg = palette.foreground.red }) -- yaml ":"
-- strings
vim.api.nvim_set_hl(0, "TSString", { fg = palette.foreground.yellow }) -- basic strings
