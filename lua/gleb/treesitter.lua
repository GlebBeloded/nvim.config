-- nvim-treesitter main branch (requires Neovim 0.11+ and the `tree-sitter` CLI:
-- `brew install tree-sitter-cli`). Neovim ships the treesitter *engine* but only
-- 7 grammars; the rest are compiled into ~/.local/share/nvim/site on first run.
---@type gleb.Languages
local languages = require("gleb.languages")

languages.register_facet("treesitter", function(config, language)
	if not vim.islist(config.parsers) then
		return ("languages: %s has invalid treesitter facet"):format(language.name)
	end
end)

---@type string[]
local parsers = {
	"markdown",
	"markdown_inline",
	"vim",
	"vimdoc",
}
for _, facet in ipairs(languages.facet("treesitter")) do
	vim.list_extend(parsers, facet.config.parsers)
end

-- skips anything already built, so this is cheap on every startup
require("nvim-treesitter").install(parsers)

-- Enable treesitter highlighting for all filetypes
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("gleb_treesitter", { clear = true }),
	callback = function()
		pcall(vim.treesitter.start)
	end,
})
