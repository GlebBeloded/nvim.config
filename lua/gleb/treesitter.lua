-- nvim-treesitter main branch (requires Neovim 0.11+ and the `tree-sitter` CLI:
-- `brew install tree-sitter-cli`). Neovim ships the treesitter *engine* but only
-- 7 grammars; the rest are compiled into ~/.local/share/nvim/site on first run.
---@type gleb.Languages
local languages = require("gleb.languages")

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

---@return string?
local function installed_plugin()
	local files = vim.api.nvim_get_runtime_file("lua/nvim-treesitter/init.lua", false)
	local file = files[1] and vim.uv.fs_realpath(files[1])
	if not file then
		return nil
	end
	return vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(file)))
end

if vim.env.GLEB_TEST_SANDBOX then
	local missing = vim.tbl_filter(function(parser)
		local ok, loaded = pcall(vim.treesitter.language.add, parser)
		return not ok or not loaded
	end, parsers)
	if #missing > 0 then
		vim.notify("Missing Treesitter parsers: " .. table.concat(missing, ", "), vim.log.levels.WARN)
	end
else
	local treesitter = require("nvim-treesitter")
	local plugin = installed_plugin()
	if plugin then
		require("gleb.treesitter.repair").repair(vim.fs.joinpath(vim.fn.stdpath("data"), "site"), plugin)
	end

	-- skips anything already built, so this is cheap on every startup
	treesitter.install(parsers)
end

-- Enable treesitter highlighting for all filetypes
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("gleb_treesitter", { clear = true }),
	callback = function()
		pcall(vim.treesitter.start)
	end,
})
