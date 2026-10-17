local settings_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h") .. "/settings.json"

---@type gleb.Language
return {
	name = "lua",
	filetypes = { "lua" },
	lsp = {
		servers = { "lua_ls" },
		config = { settings = { Lua = vim.json.decode(table.concat(vim.fn.readfile(settings_path), "\n")) } },
		mason = { "lua-language-server", "selene", "stylua" },
		null_ls = function(null_ls)
			return { null_ls.builtins.diagnostics.selene, null_ls.builtins.formatting.stylua }
		end,
	},
	treesitter = { parsers = { "lua" } },
	references = {
		test_patterns = { "_spec%.lua$", "/spec/", "/tests/" },
		usage_types = { disabled = "queued: fix-references-usage-types-lua-bash-terraform" },
		write_access = "documentHighlight",
		target_kinds = {},
		fixture = { project = "luaproj", symbol = "total" },
	},
}
