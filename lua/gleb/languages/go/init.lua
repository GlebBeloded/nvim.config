---@type gleb.Language
return {
	name = "go",
	filetypes = { "go", "gomod" },
	lsp = {
		servers = { "gopls" },
		config = {
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
		},
		mason = {
			"delve",
			"go-debug-adapter",
			"gofumpt",
			"golangci-lint",
			"golines",
			"gomodifytags",
			"gopls",
			"impl",
			"json-to-struct",
		},
		null_ls = function(null_ls)
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
		end,
	},
	treesitter = { parsers = { "go", "gomod" } },
	references = {
		test_patterns = { "_test%.go$" },
		usage_types = true,
		write_access = "documentHighlight",
		target_kinds = {},
		fixture = { project = "gomod", symbol = "Format" },
	},
}
