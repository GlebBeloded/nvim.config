local M = {}

M.lsp_name = "yamlls"
M.mason = { "yaml-language-server" }

M.lsp_config = require("yaml-companion").setup({
	lspconfig = {
		settings = {
			yaml = {
				schemas = require("gleb.lsp.config.yaml.schemas"),
			},
		},
	},
})

return M
