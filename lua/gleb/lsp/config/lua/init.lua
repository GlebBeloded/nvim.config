local M = {}

-- lsp_name is server name, to be passed as lspconfig["M.lsp_name"] = M.lsp_config
M.lsp_name = "lua"

-- table returned by this function is passed to null_ls(linter) setup
-- table should contain list of diagnostics to use
M.null_ls = function(null_ls)
  return {
    null_ls.builtins.diagnostics.selene,
    null_ls.builtins.formatting.stylua,
  }
end

-- string array that is passed to mason.EnsureInstalled method
M.mason = {
  "selene", -- linter
  "stylua" -- formatter
}


-- lua nvim autocomplitions stuff
local luadev = require("lua-dev").setup()

local config = {
  settings = {
    Lua = {
      runtime = {
        version = "LuaJIT",
      },
      diagnostics = {
        enable = true,
        globals = { "vim", "use" },
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

-- native lsp config
M.lsp_config = config

return M
