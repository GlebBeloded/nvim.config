---@type gleb.Language
return {
	name = "python",
	filetypes = { "python" },
	lsp = { servers = { "basedpyright", "ruff" }, config = {}, mason = { "basedpyright", "ruff" } },
	treesitter = { parsers = { "python" } },
	references = {
		test_patterns = { "/test_[^/]*%.py$", "/[^/]*_test%.py$", "/conftest%.py$", "/tests/" },
		usage_types = { disabled = "queued: fix-references-usage-types-python" },
		write_access = "documentHighlight",
		target_kinds = {},
		fixture = { project = "pyproj", symbol = "total" },
	},
}
