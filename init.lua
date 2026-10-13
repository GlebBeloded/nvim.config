-- if ever lost, user :help lua-guide

-- before lazy.nvim: plugins bind their leader maps while loading
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- debug plugin which writes to /tmp before any plugin loads
require("gleb.nvim_debug_log").setup()

require("gleb.plugins")
require("gleb.options")
require("gleb.colors")
require("gleb.keymaps") -- after plugins: needs smart-splits and telescope
require("gleb.cmp")
require("gleb.lsp")
require("gleb.telescope")
require("gleb.select")
require("gleb.treesitter")
require("gleb.folding") -- must be after treesitter
require("gleb.autopairs") -- must be after treesitter
require("gleb.comments") -- must be after treesitter
require("gleb.git")
require("gleb.run")
require("gleb.bufferline")
require("gleb.project")
require("gleb.indentline")
require("gleb.session") -- before alpha: restored buffers make alpha self-skip
require("gleb.alpha")
require("gleb.autocommands")
require("gleb.statusline") -- try to put after plugins that create splits
require("gleb.file_tree")
