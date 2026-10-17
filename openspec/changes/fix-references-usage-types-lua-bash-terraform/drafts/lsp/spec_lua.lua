local dir = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))
local M = "shop/cart.lua"
local P = "shop/price.lua"
return {
  name = "lua_ls",
  cmd = { vim.fn.expand("~/.local/share/nvim/mason/bin/lua-language-server") },
  root = dir .. "/lua",
  filetype = "lua",
  open = { M },
  settings = { Lua = {} },
  queries = {
    { label = "1 total (M.total def, on `total`)", file = M, line = 4, col = 11, highlight = true },
    { label = "1b total (on `M` of M.total def)", file = M, line = 4, col = 9 },
    { label = "1c total in defaults table key", file = M, line = 22, col = 4 },
    { label = "2 price local", file = M, line = 0, col = 6 },
    { label = "3 items param", file = M, line = 4, col = 17 },
    { label = "4 P.of (price.lua)", file = P, line = 4, col = 11 },
    { label = "5a P local (price.lua line0)", file = P, line = 0, col = 6 },
    { label = "5b return P", file = P, line = 8, col = 7 },
    { label = "5c require string \"shop.price\"", file = M, line = 0, col = 22 },
    { label = "5d P.key", file = P, line = 2, col = 2 },
    { label = "6 M:apply", file = M, line = 12, col = 11 },
    { label = "7 M.format", file = M, line = 17, col = 2 },
    { label = "x M local", file = M, line = 1, col = 6 },
  },
}
