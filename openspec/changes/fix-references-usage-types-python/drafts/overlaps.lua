-- Lists nodes captured by more than one pattern, showing which wins (first pattern in file).
local dir = _G.arg[1]
for _, f in ipairs({ { "usages.py", "python" } }) do
  local source = table.concat(vim.fn.readfile(dir .. "/fixtures/" .. f[1]), "\n") .. "\n"
  local root = vim.treesitter.get_string_parser(source, f[2]):parse()[1]:root()
  local q = vim.treesitter.query.get(f[2], "usages")
  local seen = {} ---@type table<string, {pattern:integer, type:string}[]>
  for pattern, match in q:iter_matches(root, source) do
    for id, nodes in pairs(match) do
      if q.captures[id]:sub(1, 6) == "usage." then
        for _, node in ipairs(nodes) do
          local sr, sc = node:range()
          local key = ("%s L%d C%d %s"):format(f[1], sr + 1, sc, vim.treesitter.get_node_text(node, source))
          seen[key] = seen[key] or {}
          table.insert(seen[key], { pattern = pattern, type = q.captures[id]:sub(7) })
        end
      end
    end
  end
  for key, list in vim.spairs(seen) do
    table.sort(list, function(a, b) return a.pattern < b.pattern end)
    local types = vim.tbl_map(function(e) return e.type .. "#" .. e.pattern end, list)
    if #vim.fn.uniq(vim.tbl_map(function(e) return e.type end, list)) > 1 then
      print(key, "winner=" .. list[1].type, table.concat(types, ","))
    end
  end
end
