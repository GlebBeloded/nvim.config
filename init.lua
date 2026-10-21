-- if ever lost, user :help lua-guide

-- before lazy.nvim: plugins bind their leader maps while loading
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

vim.loader.enable() -- before configuration imports: cache every module

-- debug plugin which writes to /tmp before any plugin loads
require("gleb.nvim_debug_log").setup()

require("gleb.plugins")
require("gleb.options")
require("gleb.colors")
require("gleb.diff.view.highlights")
require("gleb.file_tree.render").setup()
require("gleb.git.committed_signs.highlights").setup()
require("gleb.git.changes.highlights").setup()
require("gleb.file_tree.loader")
require("gleb.pr.loader")
require("gleb.select")
require("gleb.keymaps") -- after plugins: needs smart-splits
require("gleb.actions").setup({
	require("gleb.find_action.actions"),
	require("gleb.view.actions"),
	require("gleb.references.actions"),
	require("gleb.keymaps.actions"),
	require("gleb.comments.actions"),
	require("gleb.folding.actions"),
	require("gleb.ai.actions"),
	require("gleb.git.actions"),
	require("gleb.pr.actions"),
	require("gleb.diff.actions"),
	require("gleb.file_tree.actions"),
	require("gleb.autocommands.actions"),
	require("gleb.surround.actions"),
	require("gleb.cmp.actions"),
	require("gleb.copilot.actions"),
	require("gleb.debugging.actions"),
	require("gleb.testing.actions"),
	require("gleb.lsp.actions"),
	require("gleb.plugins.actions"),
	require("gleb.alpha.actions"),
})
require("gleb.languages.facets")
require("gleb.languages").validate()
require("gleb.run")
require("gleb.bufferline")
require("gleb.session") -- before alpha: restored buffers make alpha self-skip
require("gleb.alpha")
require("gleb.autocommands")
require("gleb.statusline") -- try to put after plugins that create splits
