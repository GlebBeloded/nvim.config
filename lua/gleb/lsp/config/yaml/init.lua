local M = {}

M.lsp_name = "yamlls"

M.lsp_config = {
	settings = {
		yaml = {
			schemas = require("gleb.lsp.config.yaml.schemas"),
		},
	},
}

return M
