local M = {}

M.lsp_names = { "vtsls", "eslint" }

M.lsp_config = {
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
			preferences = {
				importModuleSpecifier = "non-relative",
			},
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
		vtsls = {
			autoUseWorkspaceTsdk = true,
			experimental = {
				maxInlayHintLength = 30,
			},
		},
	},
}

M.mason = {
	"eslint-lsp",
	"eslint_d",
	"vtsls",
}

return M
