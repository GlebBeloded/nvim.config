-- usage: nvim --clean --headless --cmd 'set rtp^=~/.local/share/nvim/site' --cmd 'set rtp^=<dir>' -l verify.lua <dir>
local dir = _G.arg[1]
package.path = dir .. "/?.lua;" .. package.path
local classify = require("classify").classify
local function print(s) io.stdout:write(s, "\n") end

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

-- Target-kind refinement (fix-references-usage-types design Decision 3, plus this change's Python rule).
local TYPE_POSITION = {
  field_declaration = true, parameter_declaration = true, return_type = true, receiver = true,
  variable_declaration = true, const_declaration = true, type_alias = true, type_assertion = true,
  type_conversion = true, type_instantiation = true, type_constraint = true, type_parameter_declaration = true,
  cast = true, instanceof = true, extends = true, impl = true, catch = true,
}

---@param usage string?
---@param kind string? "function" | "type" | "field" | "variable" | "unknown"; nil = no refinement
---@return string?
local function refine(usage, kind)
  if not usage or not kind then return usage end
  if (usage == "write" or usage == "read") and (kind == "function" or kind == "type") then return nil end
  if usage == "function_argument" then return kind == "function" and usage or nil end
  if usage == "static_member" then return kind == "type" and usage or nil end
  if usage == "call" and kind == "type" then return "new" end
  if kind ~= "type" and kind ~= "unknown" and TYPE_POSITION[usage] then return nil end
  return usage
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
      local raw, first = classify(root, source, case.lang, line - 1, col)
      local got = refine(raw, e.kind)
      local ok = (got or false) == want and (refine(first, e.kind) or false) == want
      if not ok then failed = failed + 1 end
      print(("%s L%-3d C%-3d %-22s want=%-22s got=%s%s%s"):format(ok and "PASS" or "FAIL", line, col, needle,
        tostring(want or "-"), tostring(got or "-"), e.kind and (" kind=" .. e.kind .. " raw=" .. tostring(raw)) or "",
        (first or false) ~= (raw or false) and (" captures-order=" .. tostring(first)) or ""))
    end
  end
end
print(("%d/%d passed"):format(total - failed, total))
if failed > 0 then os.exit(1) end
