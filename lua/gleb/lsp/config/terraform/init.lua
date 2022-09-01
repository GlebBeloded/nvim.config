local M = {}

-- lsp_name is server name, to be passed as lspconfig["M.lsp_name"] = M.lsp_config
M.lsp_name = "terraform_lsp"

-- native lsp config
M.lsp_config = { filetypes = { "terraform", "tf", "hcl" } }

-- table returned by this function is passed to null_ls(linter) setup
-- table should contain list of diagnostics to use
M.null_ls = function(null_ls)
	return { null_ls.builtins.formatting.terraform_fmt }
end

-- string array that is passed to mason.EnsureInstalled method
M.mason = {
	"terraform-ls",
}

return M
