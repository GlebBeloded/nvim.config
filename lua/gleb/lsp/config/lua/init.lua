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
	"lua-language-server", -- language server (mason package name)
	"selene", -- linter
	"stylua", -- formatter
}

-- load settings from JSON
-- some black magic to get relative path to json schema file
local settings_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h") .. "/settings.json"

local config = {
	settings = {
		Lua = vim.json.decode(table.concat(vim.fn.readfile(settings_path), "\n")),
	},
}

-- native lsp config
M.lsp_config = config

return M
