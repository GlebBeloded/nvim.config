local M = {}

-- rust-analyzer is managed by rustaceanvim (see lua/gleb/plugins/plugins.lua),
-- so we intentionally don't expose lsp_name here — the lspconfig loop will skip it.

M.null_ls = function(_)
	return {}
end

-- mason still installs the binaries; rustaceanvim picks rust-analyzer up from PATH.
M.mason = {
	"rust-analyzer",
	"rustfmt",
}

return M
