local M = {}

M.lsp_name = "jsonls"

M.mason = { "json-lsp" }

M.lsp_config = {
	settings = {
		json = {
			schemas = require("gleb.lsp.config.json.schemas"),
			validate = { enable = true }, -- check JSON syntax validity
		},
	},
}

return M
