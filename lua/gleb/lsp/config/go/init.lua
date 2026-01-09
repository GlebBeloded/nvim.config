local M = {}

-- lsp_name is server name, to be passed as lspconfig["M.lsp_name"] = M.lsp_config
M.lsp_name = "gopls"

-- gopls settings: https://go.dev/gopls/settings
-- https://github.com/golang/tools/blob/master/gopls/doc/inlayHints.md
M.lsp_config = {
	settings = {
		gopls = {
			gofumpt = false,
			hints = {
				assignVariableTypes = false,
				compositeLiteralFields = true,
				constantValues = true,
				parameterNames = false,
			},
			semanticTokens = true,
		},
	},
}

-- table returned by this function is passed to null_ls(linter) setup
-- table should contain list of diagnostics to use
M.null_ls = function(null_ls)
	return {
		null_ls.builtins.diagnostics.golangci_lint.with({
			args = {
				"run",
				"--output.json.path=stdout",
				"--show-stats=false",
				"$DIRNAME",
				"--path-prefix",
				"$ROOT",
			},
		}),
	}
end

-- string array that is passed to mason.EnsureInstalled method
M.mason = {
	"delve",
	"go-debug-adapter",
	"gofumpt",
	"golangci-lint",
	"golines",
	"gomodifytags",
	"gopls",
	"impl",
	"json-to-struct",
}

return M
