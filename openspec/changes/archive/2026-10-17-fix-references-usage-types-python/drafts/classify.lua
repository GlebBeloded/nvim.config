---@class usages.Classifier
local M = {}

---Classify the node starting at (row, col) (0-based) using queries/<lang>/usages.scm.
---Precedence: lowest pattern index wins among matches capturing a node that starts there.
---@param source string
---@param lang string
---@param row integer
---@param col integer
---@return string? type_id, string? via_captures
function M.classify(root, source, lang, row, col)
  local query = vim.treesitter.query.get(lang, "usages")
  assert(query, "no usages query for " .. lang)
  local best_pattern, best_type
  for pattern, match in query:iter_matches(root, source, row, row + 1) do
    for id, nodes in pairs(match) do
      local name = query.captures[id]
      if name:sub(1, 6) == "usage." then
        for _, node in ipairs(nodes) do
          local sr, sc = node:range()
          if sr == row and sc == col and (not best_pattern or pattern < best_pattern) then
            best_pattern, best_type = pattern, name:sub(7)
          end
        end
      end
    end
  end
  -- cross-check: first capture emitted by iter_captures for that node
  local first
  for id, node in query:iter_captures(root, source, row, row + 1) do
    local name = query.captures[id]
    local sr, sc = node:range()
    if sr == row and sc == col and name:sub(1, 6) == "usage." then
      first = name:sub(7)
      break
    end
  end
  return best_type, first
end

return M
