local M = {}

-- lsp_name is server name, to be passed as lspconfig["M.lsp_name"] = M.lsp_config
M.lsp_name = "sumneko_lua"

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
	"selene", -- linter
	"stylua", -- formatter
}

local config = {
	settings = {
		Lua = {
			runtime = {
				version = "LuaJIT",
			},
			diagnostics = {
				-- Get the language server to recognize the `vim` global
				globals = { "vim" },
			},
			workspace = {
				library = {
					[vim.fn.expand("$VIMRUNTIME/lua")] = true,
					[vim.fn.stdpath("config") .. "/lua"] = true,
				},
			},
		},
	},
}

-- lua nvim autocomplitions stuff
config = vim.tbl_deep_extend("force", config, require("lua-dev").setup())

-- native lsp config
M.lsp_config = config

return M
