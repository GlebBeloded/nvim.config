-- IMPORTANT: make sure to setup neodev BEFORE lspconfig
require("neodev").setup({
	-- add any options here, or leave empty to use the default settings
})

local M = {}

-- lsp_name is server name, to be passed as lspconfig["M.lsp_name"] = M.lsp_config
M.lsp_name = "lua_ls"

-- table returned by this function is passed to null_ls(linter) setup
-- table should contain list of diagnostics to use
M.null_ls = function(null_ls)
	return {
		null_ls.builtins.diagnostics.selene,
		null_ls.builtins.formatting.stylua,
	}
end

-- string array that is passed to mason.EnsureInstalled method
M.mason = {
	"lua_ls", -- language server
	"selene", -- linter
	"stylua", -- formatter
}

local config = {
	settings = {
		Lua = {
			completion = {
				callSnippet = "Replace",
			},
		},
	},
}

-- native lsp config
M.lsp_config = config

return M
