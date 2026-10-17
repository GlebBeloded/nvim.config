local dir = _G.arg[1]
package.path = dir .. "/?.lua;" .. package.path
local classify = require("classify").classify
local source = table.concat(vim.fn.readfile(dir .. "/fixtures/usages.rs"), "\n") .. "\n"
local parser = vim.treesitter.get_string_parser(source, "rust")
parser:parse(true)
for _, spec in ipairs({ { 40, 26, "local" }, { 40, 32, "name" }, { 40, 38, "n" }, { 41, 15, "local" } }) do
  local row, col = spec[1], spec[2]
  local ltree = parser:language_for_range({ row, col, row, col })
  local tree = ltree:tree_for_range({ row, col, row, col }, { ignore_injections = false })
  local inj = classify(tree:root(), source, "rust", row, col)
  local top = classify(parser:trees()[1]:root(), source, "rust", row, col)
  print(spec[3], "top-level tree:", top, "injected tree:", inj, "is_child:", ltree ~= parser)
end
