local M = {}

M.lsp_name = "vtsls"

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

-- Note: eslint_d builtin was removed from none-ls
-- ESLint diagnostics are now provided by eslint-lsp via native LSP
M.null_ls = function(null_ls)
	return {
		null_ls.builtins.code_actions.refactoring,
	}
end

M.mason = {
	"eslint-lsp",
	"eslint_d",
	"vtsls",
}

return M
