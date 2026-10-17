---@type gleb.Language
return {
	name = "shell",
	filetypes = { "sh", "bash", "zsh" },
	lsp = {
		servers = { "bashls" },
		config = { settings = { bashIde = { globPattern = "**/*@(.sh|.inc|.bash|.command)" } } },
		mason = { "bash-language-server", "shfmt", "shellharden" },
		null_ls = function(null_ls)
			return {
				null_ls.builtins.diagnostics.zsh,
				null_ls.builtins.formatting.shfmt,
				null_ls.builtins.formatting.shellharden,
			}
		end,
	},
	treesitter = { parsers = { "bash" } },
	references = {
		test_patterns = { "%.bats$", "/test/", "/tests/" },
		usage_types = { disabled = "queued: fix-references-usage-types-lua-bash-terraform" },
		write_access = false,
		target_kinds = {},
		fixture = { project = "bashproj", symbol = "total" },
	},
}
