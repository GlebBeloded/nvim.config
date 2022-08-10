local lspconfig = require("lspconfig")
-- lua nvim autocomplitions stuff
local luadev = require("lua-dev").setup()

local config = {
  settings = {

    Lua = {
      diagnostics = {
        globals = { "vim" },
      },
      workspace = {
        library = {
          [vim.fn.expand("$VIMRUNTIME/lua")] = true,
          [vim.fn.stdpath("config") .. "/lua"] = true,
        },
      },
    },
  },
}

config = vim.tbl_deep_extend("force", config, luadev)

lspconfig.sumneko_lua.setup(config)
