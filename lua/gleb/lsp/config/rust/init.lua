local M = {}

-- lsp_name is server name, to be passed as lspconfig["M.lsp_name"] = M.lsp_config
M.lsp_name = "rust_analyzer"

-- native lsp config
M.lsp_config = {
	settings = {},
}

-- table returned by this function is passed to null_ls(linter) setup
-- table should contain list of diagnostics to use
M.null_ls = function(null_ls)
	return {
		null_ls.builtins.formatting.rustfmt,
	}
end

-- string array that is passed to mason.EnsureInstalled method
M.mason = {
	"rust-analyzer",
}

return M
