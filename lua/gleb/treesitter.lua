-- nvim-treesitter main branch (requires Neovim 0.11+)
-- Parsers installed via :TSInstall or lazy.nvim build = ':TSUpdate'

-- Enable treesitter highlighting for all filetypes
vim.api.nvim_create_autocmd("FileType", {
	callback = function()
		pcall(vim.treesitter.start)
	end,
})
