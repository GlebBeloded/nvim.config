-- nvim-treesitter main branch (requires Neovim 0.11+ and the `tree-sitter` CLI:
-- `brew install tree-sitter-cli`). Neovim ships the treesitter *engine* but only
-- 7 grammars; the rest are compiled into ~/.local/share/nvim/site on first run.
---@type string[]
local parsers = {
	"bash",
	"go",
	"gomod",
	"hcl",
	"json",
	"lua",
	"markdown",
	"markdown_inline",
	"vim",
	"vimdoc",
	"yaml",
}

-- skips anything already built, so this is cheap on every startup
require("nvim-treesitter").install(parsers)

-- Enable treesitter highlighting for all filetypes
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("gleb_treesitter", { clear = true }),
	callback = function()
		pcall(vim.treesitter.start)
	end,
})
