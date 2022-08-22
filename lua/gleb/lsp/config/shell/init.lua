local M = {}

-- lsp_name is server name, to be passed as lspconfig["M.lsp_name"] = M.lsp_config
M.lsp_name = "bashls"

-- native lsp config
M.lsp_config = {}

-- table returned by this function is passed to null_ls(linter) setup
-- table should contain list of diagnostics to use
M.null_ls = function(null_ls)
	return {
		null_ls.builtins.diagnostics.zsh,
		null_ls.builtins.diagnostics.shellcheck,
		null_ls.builtins.code_actions.shellcheck,
		null_ls.builtins.formatting.shfmt,
	}
end

-- string array that is passed to mason.EnsureInstalled method
M.mason = {
	"bash-language-server",
	"shellcheck",
	"shfmt",
}

return M
