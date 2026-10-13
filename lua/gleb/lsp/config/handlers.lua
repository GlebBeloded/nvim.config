-- this file holds handlers for lsp clinet which can be reused by all language clients
local M = {}

M.setup = function()
	local config = {
		virtual_text = {
			prefix = "",
			spacing = 0,
		},
		signs = {
			text = {
				[vim.diagnostic.severity.ERROR] = "",
				[vim.diagnostic.severity.WARN] = "",
				[vim.diagnostic.severity.HINT] = "",
				[vim.diagnostic.severity.INFO] = "",
			},
		},
		update_in_insert = false,
		underline = true,
		severity_sort = true,
		float = {
			focusable = false,
			style = "minimal",
			border = "rounded",
			source = "always",
			header = "",
			prefix = "",
		},
	}

	vim.diagnostic.config(config)

	-- enable inlay hints globally
	vim.lsp.inlay_hint.enable(true)
end

-- blink.cmp provides its own capabilities
M.capabilities = require("blink.cmp").get_lsp_capabilities(vim.lsp.protocol.make_client_capabilities())

return M
