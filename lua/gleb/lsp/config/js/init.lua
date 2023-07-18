local M = {}

-- lsp_name is server name, to be passed as lspconfig["M.lsp_name"] = M.lsp_config
M.lsp_name = "tsserver"

-- native lsp config
M.lsp_config = {}

-- table returned by this function is passed to null_ls(linter) setup
-- table should contain list of diagnostics to use
M.null_ls = function(null_ls)
	return {
		null_ls.builtins.diagnostics.eslint_d,
		null_ls.builtins.code_actions.refactoring,
	}
end

-- string array that is passed to mason.EnsureInstalled method
M.mason = {
	"eslint-lsp",
	"eslint_d",
	"sonarlint-language-server",
	"typescript-language-server",
}

return M
