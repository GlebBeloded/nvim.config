local M = {}

-- function passed to nvim lsp
local on_attach = function(client, buffer)
  local lsp_lines_config = {
    bind = true,
    hint_enable = true, -- virtal text hint
    floating_window = false, -- floating window hint
    hint_prefix = "",
    hint_scheme = "Comment", -- how your parameter will be highlight (highlight color)
  }

  print(lsp_lines_config.hi_parameter)
  require "lsp-format".on_attach(client) -- fmt on file save
  require "lsp_signature".on_attach(lsp_lines_config, buffer) -- pretty signatures
end


-- lsp_name returns server name, to be passed as lspconfig["M.lsp_name"] = M.lsp_config
M.lsp_name = function()
  return "gopls"
end



-- this function sets up native lsp to use go
M.lsp_config = function()
  return { on_attach = on_attach }
end

-- table returned by this function is passed to null_ls(linter) setup
M.null_ls = function(null_ls)
  return {
    null_ls.builtins.diagnostics.golangci_lint.with({
      method = null_ls.methods.DIAGNOSTICS,
      args = { "run", "--fix=false", "--enable-all", "--out-format=json", "$DIRNAME", "--path-prefix", "$ROOT" }
    }),
  }
end

-- this function returns string array that is passed to mason.EnsureInstalled method
M.mason = function()
  return {
    "delve",
    "go-debug-adapter",
    "gofumpt",
    "golangci_lint",
    "golines",
    "gomodifytags",
    "gopls",
    "impl",
    "json-to-struct",
  }
end

return M
