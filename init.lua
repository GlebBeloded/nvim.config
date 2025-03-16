-- https://github.com/nanotee/nvim-lua-guide#tips-2
-- if ever lost, user :help lua-guide

require("gleb.plugins")
require("gleb.options")
require("gleb.colors") -- must be loaded before lazy.nvim
require("gleb.keymaps") -- mapleader keymap must be before lazy.nivm
require("gleb.cmp")
require("gleb.lsp")
require("gleb.telescope")
require("gleb.select")
require("gleb.treesitter")
require("gleb.folding") -- must be after treesitter
require("gleb.autopairs") -- must be after treesitter
require("gleb.comments") -- must be after treesitter
-- require("gleb.git")
require("gleb.run")
require("gleb.debugging")
require("gleb.bufferline")
require("gleb.project")
require("gleb.indentline")
require("gleb.alpha-nvim")
require("gleb.autocommands")
require("gleb.lualine") -- try to put after plugins that create splits
require("gleb.file_tree")
