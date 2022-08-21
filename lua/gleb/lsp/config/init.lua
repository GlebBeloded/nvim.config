local config = require("gleb/lsp/config/handlers")
config.setup()
local go_config = require("gleb/lsp/config/go")

local function merge(...)
  return vim.tbl_deep_extend("force", ...)
end

require("mason").setup()
require("mason-lspconfig").setup {
  -- A list of servers to automatically install if they're not already installed. Example: { "rust_analyzer@nightly", "sumneko_lua" }
  -- This setting has no relation with the `automatic_installation` setting.
  ensure_installed = go_config.mason(),
}

require("lspconfig")[go_config.lsp_name()].setup(merge(config, go_config.lsp_config()))

local null_ls = require("null-ls")
null_ls.setup({
  debug = false,
  update_in_insert = false,
  sources = {go_config.null_ls(null_ls), null_ls.builtins.diagnostics.zsh, null_ls.builtins.formatting.beautysh, null_ls.builtins.formatting.prettier},
})

require("gleb/lsp/config/json")
require("gleb/lsp/config/lua")

vim.cmd [[ set updatetime=1000 ]] -- this variable configures how long does it tike before CursorHold event fires

-- TODO: move to it's own directory
require("lspconfig").yamlls.setup({
  settings = {
    yaml = {
      schemas = {
        ["https://gitlab.com/gitlab-org/gitlab/-/raw/master/app/assets/javascripts/editor/schema/ci.json?inline=false"] = "*/.gitlab-ci.yaml",
      }
    }
  }
})

require("lspconfig").jsonls.setup(merge(config, require("gleb.lsp.config.json")))
