local M = {}

-- lsp_name is server name, to be passed as lspconfig["M.lsp_name"] = M.lsp_config
M.lsp_name = "gopls"

-- native lsp config
M.lsp_config = {
  settings = {
    gopls = {
      buildFlags = { "-tags=integration" },
      gofumpt = false,
    }
  },
}

-- table returned by this function is passed to null_ls(linter) setup
-- table should contain list of diagnostics to use
M.null_ls = function(null_ls)
  return {
    null_ls.builtins.diagnostics.golangci_lint.with({
      method = null_ls.methods.DIAGNOSTICS,
      args = {
        "run",
        "--fix=false",
        "--enable-all",
        "--out-format=json",
        "$DIRNAME",
        "--path-prefix",
        "$ROOT"
      }
    })
  }
end

-- string array that is passed to mason.EnsureInstalled method
M.mason = {
  "delve",
  "go-debug-adapter",
  "gofumpt",
  "golangci-lint",
  "golines",
  "gomodifytags",
  "gopls",
  "impl",
  "json-to-struct",
}

return M
