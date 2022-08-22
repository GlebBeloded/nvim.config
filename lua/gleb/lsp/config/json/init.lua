local M = {}

M.lsp_name = "jsonls"

M.lsp_config = {
	settings = {
		json = {
			schemas = require("gleb.lsp.config.json.schemas"),
		},
	},
	setup = {
		commands = {
			Format = {
				function()
					vim.lsp.buf.range_formatting({}, { 0, 0 }, { vim.fn.line("$"), 0 })
				end,
			},
		},
	},
}

return M
