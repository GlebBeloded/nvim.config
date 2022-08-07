-- this file includes lsp configs for all the linetrs / lsp clients

vim.cmd [[ set updatetime=1000 ]] -- this variable configures how long does it tike before CursorHold event fires

local M = {}

M.setup = function()
  require("mason").setup()
  local servers = { "jsonls", "sumneko_lua", "gopls", "golangci-lint-langserver" }
  require("mason-lspconfig").setup {
    ensure_installed = servers,
  }

  require("gleb/lsp/config/handlers").setup()
  require("gleb/lsp/config/go")
  require("gleb/lsp/config/json")
  require("gleb/lsp/config/lua")
end

return M
