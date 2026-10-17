-- Usage: nvim -l tree.lua <lang> <file>: print named nodes with field names and ranges.
local lang, file = arg[1], arg[2]
local src = table.concat(vim.fn.readfile(file), "\n") .. "\n"
local root = vim.treesitter.get_string_parser(src, lang):parse()[1]:root()
local function walk(node, field, depth)
  local sr, sc, er, ec = node:range()
  local leaf = node:named_child_count() == 0 and (" " .. vim.inspect(vim.treesitter.get_node_text(node, src))) or ""
  print(("%s%s%s [%d:%d-%d:%d]%s"):format(string.rep("  ", depth), field and (field .. ": ") or "", node:type(), sr, sc, er, ec, leaf))
  for child, f in node:iter_children() do
    if child:named() then walk(child, f, depth + 1) end
  end
end
walk(root, nil, 0)
