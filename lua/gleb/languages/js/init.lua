---@type gleb.Language
return {
	name = "js",
	filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
	lsp = {
		servers = { "vtsls", "eslint" },
		config = {
			settings = {
				typescript = {
					inlayHints = {
						parameterNames = { enabled = "literals" },
						parameterTypes = { enabled = true },
						variableTypes = { enabled = true },
						propertyDeclarationTypes = { enabled = true },
						functionLikeReturnTypes = { enabled = true },
						enumMemberValues = { enabled = true },
					},
					preferences = { importModuleSpecifier = "non-relative" },
				},
				javascript = {
					inlayHints = {
						parameterNames = { enabled = "literals" },
						parameterTypes = { enabled = true },
						variableTypes = { enabled = true },
						propertyDeclarationTypes = { enabled = true },
						functionLikeReturnTypes = { enabled = true },
						enumMemberValues = { enabled = true },
					},
				},
				vtsls = { autoUseWorkspaceTsdk = true, experimental = { maxInlayHintLength = 30 } },
			},
		},
		mason = { "eslint-lsp", "eslint_d", "vtsls" },
	},
	treesitter = { parsers = { "javascript", "typescript", "tsx" } },
	references = {
		test_patterns = { "%.test%.[^/]+$", "%.spec%.[^/]+$", "/__tests__/" },
		usage_types = { disabled = "queued: fix-references-usage-types-typescript" },
		write_access = "tsserver",
		target_kinds = {},
		fixture = { project = "tsproj", symbol = "total" },
	},
}
