local lspconfig = require("lspconfig")

local config = {
}


config.on_attach = require("gleb/lsp/config/handlers").on_attach
config.capabilities = require("gleb/lsp/config/handlers").capabilities

lspconfig.gopls.setup(config)
