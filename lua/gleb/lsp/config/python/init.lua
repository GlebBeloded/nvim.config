local M = {}

-- :PyTypeCheckOn / :PyTypeCheckOff toggle basedpyright type checking
require("gleb.lsp.config.python.typecheck").setup()

-- lsp_names: servers configured via vim.lsp.config + vim.lsp.enable
M.lsp_names = { "basedpyright", "ruff" }

-- string array that is passed to mason.EnsureInstalled method
M.mason = {
	"basedpyright", -- language server (mason package name)
	"ruff", -- linter + formatter
}

-- native lsp config
M.lsp_config = {}

return M
