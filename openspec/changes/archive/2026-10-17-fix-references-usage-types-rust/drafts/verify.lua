-- usage: nvim --clean --headless --cmd 'set rtp^=~/.local/share/nvim/site' --cmd 'set rtp^=<dir>' -l verify.lua <dir>
local dir = _G.arg[1]
package.path = dir .. "/?.lua;" .. package.path
local classify = require("classify").classify

---@param lines string[]
---@param line integer 1-based
---@param needle string
---@param nth integer
---@return integer? col 0-based
local function find_col(lines, line, needle, nth)
  local text, init, seen = lines[line], 1, 0
  while true do
    local s, e = text:find(needle, init, true)
    if not s then return nil end
    local before, after = text:sub(s - 1, s - 1), text:sub(e + 1, e + 1)
    if not before:match("[%w_]") and not after:match("[%w_]") then
      seen = seen + 1
      if seen == nth then return s - 1 end
    end
    init = e + 1
  end
end

local total, failed = 0, 0
for _, case in ipairs(dofile(dir .. "/expected.lua")) do
  local lines = vim.fn.readfile(dir .. "/fixtures/" .. case.file)
  local source = table.concat(lines, "\n") .. "\n"
  local root = vim.treesitter.get_string_parser(source, case.lang):parse()[1]:root()
  print(("== %s (%s)"):format(case.file, case.lang))
  for _, e in ipairs(case.expect) do
    local line, needle, want, nth = e[1], e[2], e[3] or false, e.nth or 1
    local col = find_col(lines, line, needle, nth)
    total = total + 1
    if not col then
      failed = failed + 1
      print(("FAIL L%d %-22s needle not found"):format(line, needle))
    else
      local got, first = classify(root, source, case.lang, line - 1, col)
      local ok = (got or false) == want and (first or false) == want
      if not ok then failed = failed + 1 end
      print(("%s L%-3d C%-3d %-22s want=%-22s got=%s%s"):format(ok and "PASS" or "FAIL", line, col, needle,
        tostring(want or "-"), tostring(got or "-"), (first or false) ~= (got or false) and (" captures-order=" .. tostring(first)) or ""))
    end
  end
end
print(("%d/%d passed"):format(total - failed, total))
if failed > 0 then os.exit(1) end
