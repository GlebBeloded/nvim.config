local s = dofile(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)) .. "/spec_lua.lua")
local M = "shop/cart.lua"
s.queries = {
  { label = "3b items in ---@param doc", file = M, line = 3, find = "items", highlight = true },
  { label = "3c items param (highlight)", file = M, line = 4, find = "items", highlight = true },
  { label = "1d cart.total in emit", file = M, line = 32, find = "cart.total", off = 5 },
  { label = "1e total key in emit table", file = M, line = 32, find = "total" },
  { label = "6b cart:apply call", file = M, line = 33, find = "apply" },
  { label = "1f M.total call site", file = M, line = 14, find = "total" },
  { label = "7b M.format call site", file = M, line = 30, find = "format", highlight = true },
  { label = "7c defaults format key", file = M, line = 23, find = "format" },
}
return s
