---@type gleb.Language
return {
	name = "terraform",
	filetypes = { "terraform", "tf", "hcl" },
	lsp = {
		servers = { "terraformls" },
		config = { filetypes = { "terraform", "tf", "hcl" } },
		mason = { "terraform-ls" },
		null_ls = function(null_ls)
			if vim.fn.executable("terraform") ~= 1 then
				return {}
			end
			return { null_ls.builtins.formatting.terraform_fmt }
		end,
	},
	treesitter = { parsers = { "hcl", "terraform" } },
	references = {
		test_patterns = { "%.tftest%.hcl$", "/tests/" },
		usage_types = { disabled = "queued: fix-references-usage-types-lua-bash-terraform" },
		write_access = "documentHighlight",
		target_kinds = { Class = "unknown" },
		fixture = { project = "tfproj", symbol = "region" },
	},
}
