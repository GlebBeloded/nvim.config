local src = "local t = { a = 1, [k] = 2, b = function() end }\nlocal first, second\nfor i = 1, 2 do end\nfor k, v in pairs(t) do end\n"
local q = vim.treesitter.query.parse("lua", [[
(field name: (identifier) @A . "=")
(field name: (identifier) @B)
(identifier) @C
]])
local root = vim.treesitter.get_string_parser(src, "lua"):parse()[1]:root()
for id, node, _, match in q:iter_captures(root, src, 0, -1) do
  local r, c = node:range()
  print(r, c, q.captures[id], vim.treesitter.get_node_text(node, src), "pattern", match:info())
end
print(root:sexpr())
