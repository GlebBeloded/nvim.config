-- this file holds handlers for lsp clinet which can be reused by all language clients
local M = {}

M.setup = require("gleb/lsp/config/handlers/setup")

M.on_attach = require("gleb/lsp/config/handlers/on_attach")

M.capabilities = require("gleb/lsp/config/handlers/capabilities")

return M
