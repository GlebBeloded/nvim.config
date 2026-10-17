---@type gleb.Language
return {
	name = "rust",
	filetypes = { "rust" },
	lsp = {
		servers = {},
		mason = { "rust-analyzer", "rustfmt" },
		null_ls = function(_)
			return {}
		end,
	},
	treesitter = { parsers = { "rust" } },
	references = {
		test_patterns = { "/tests/" },
		usage_types = { disabled = "queued: fix-references-usage-types-rust" },
		write_access = "documentHighlight",
		target_kinds = {},
		fixture = { project = "rustproj", symbol = "total" },
	},
}
