-- usage: nvim -l dump.lua <lang> <file>
local lang, file = _G.arg[1], _G.arg[2]
local src = table.concat(vim.fn.readfile(file), "\n")
local parser = vim.treesitter.get_string_parser(src, lang)
local root = parser:parse()[1]:root()
local function walk(node, depth, field)
  local sr, sc = node:range()
  local txt = ""
  if node:named_child_count() == 0 then txt = " " .. vim.treesitter.get_node_text(node, src):sub(1,30) end
  if node:named() then
    print(string.rep("  ", depth) .. (field and (field .. ": ") or "") .. node:type() .. " [" .. sr .. ":" .. sc .. "]" .. txt)
  end
  for child, f in node:iter_children() do
    if child:named() then walk(child, depth + 1, f) end
  end
end
walk(root, 0)
