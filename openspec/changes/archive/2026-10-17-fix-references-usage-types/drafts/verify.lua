-- Verifies queries/<lang>/usages.scm against fixtures/*.  Usage (from this dir):
--   nvim --clean --headless --cmd 'set rtp^=~/.local/share/nvim/site' \
--     --cmd 'set rtp^=<this dir>' -l verify.lua [cases.lua] [-v]
local dir = vim.fs.dirname(vim.fs.abspath(arg[0]))
local cases_path = (arg[1] and arg[1] ~= "-v") and arg[1] or (dir .. "/cases.lua")
local verbose = vim.list_contains(arg, "-v")

---@class UsageHit
---@field type string usage type id (capture name without the `usage.` prefix)
---@field pattern integer pattern index (lower wins)

--- All usage captures whose node starts exactly at (row, col), best first.
---@param source string
---@param lang string
---@param row integer 0-based
---@param col integer 0-based byte column
---@return UsageHit[]
local function usage_hits(source, lang, row, col)
  local parser = vim.treesitter.get_string_parser(source, lang)
  local root = parser:parse()[1]:root()
  local query = assert(vim.treesitter.query.get(lang, "usages"), "no usages query for " .. lang)
  local hits = {} ---@type UsageHit[]
  for pattern, match in query:iter_matches(root, source, row, row + 1) do
    for id, nodes in pairs(match) do
      local name = query.captures[id]
      local usage = name:match("^usage%.(.+)$")
      for _, node in ipairs(usage and nodes or {}) do
        local srow, scol = node:start()
        if srow == row and scol == col then
          hits[#hits + 1] = { type = usage, pattern = pattern }
        end
      end
    end
  end
  table.sort(hits, function(a, b) return a.pattern < b.pattern end)
  return hits
end

local TYPE_FREE = { import = true, call = true, new = true, function_argument = true, value_write = true }

--- Caller-side refinement using the kind of the symbol whose usages are listed
--- (e.g. from LSP semantic tokens / documentSymbol). nil kind = no refinement.
---@param usage string?
---@param kind string? "type" | "function" | "variable" | "field" | "package"
---@param lang string
---@return string?
local function refine(usage, kind, lang)
  if not usage or not kind then return usage end
  if usage == "function_argument" then return kind == "function" and usage or nil end
  if usage == "static_member" then return kind == "type" and usage or nil end
  if usage == "call" and kind == "type" and lang == "go" then return "type_conversion" end
  if not TYPE_FREE[usage] and kind ~= "type" then return nil end
  return usage
end

--- 0-based column of the nth occurrence of needle in line.
---@param line string
---@param needle string
---@param nth integer
---@return integer?
local function find_col(line, needle, nth)
  local from = 1
  for _ = 1, nth do
    local s = line:find(needle, from, true)
    if not s then return nil end
    from = s + 1
    if _ == nth then return s - 1 end
  end
end

local suites = dofile(cases_path)
local pass, fail = 0, 0
for _, suite in ipairs(suites) do
  local path = dir .. "/" .. suite.file
  local lines = vim.fn.readfile(path)
  local source = table.concat(lines, "\n") .. "\n"
  print(("== %s (%s)"):format(suite.file, suite.lang))
  for _, case in ipairs(suite.cases) do
    local lnum, needle, want = case[1], case[2], case[3] or nil
    local col = find_col(lines[lnum], needle, case.nth or 1)
    if col and case.off then col = col + case.off end
    local hits = col and usage_hits(source, suite.lang, lnum - 1, col) or {}
    local raw = hits[1] and hits[1].type or nil
    local got = refine(raw, case.kind, suite.lang)
    local ok = col ~= nil and got == want
    if ok then pass = pass + 1 else fail = fail + 1 end
    if verbose or not ok then
      local alts = {}
      for i = 2, #hits do alts[#alts + 1] = hits[i].type end
      print(("%s %3d:%-3s %-14s want=%-27s got=%-27s%s%s"):format(
        ok and "PASS" or "FAIL", lnum, col or "?", needle, tostring(want), tostring(got),
        case.kind and (" kind=" .. case.kind .. " raw=" .. tostring(raw)) or "",
        #alts > 0 and (" (shadowed: " .. table.concat(alts, ",") .. ")") or ""))
    end
  end
end
print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
