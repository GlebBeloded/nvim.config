-- Checks the extended rustproj fixture against rust-analyzer: references (includeDeclaration=false) of
-- `Money` and `cents`, each classified with queries/rust/usages.scm, plus documentHighlight kinds.
-- usage (from drafts/): nvim --clean --headless --cmd 'set rtp^=~/.local/share/nvim/site' --cmd "set rtp^=$PWD" \
--   -l lsp_check/rustproj.lua $PWD <absolute path of a built rustproj copy>
local dir, root = _G.arg[1], _G.arg[2]
package.path = dir .. "/?.lua;" .. package.path
local classify = require("classify").classify
local function out(...) io.stdout:write(table.concat({ ... }, " "), "\n"); io.stdout:flush() end
local files = { "src/money.rs", "src/ledger.rs", "tests/money.rs", "src/main.rs", "src/price.rs" }
local bufs = {}
for _, f in ipairs(files) do
  local b = vim.fn.bufadd(root .. "/" .. f); vim.fn.bufload(b); vim.bo[b].filetype = "rust"; bufs[f] = b
end
local id
for _, b in pairs(bufs) do
  id = vim.lsp.start({ name = "rust-analyzer", cmd = { vim.fn.expand("~/.local/share/nvim/mason/bin/rust-analyzer") }, root_dir = root,
    capabilities = vim.tbl_deep_extend("force", vim.lsp.protocol.make_client_capabilities(), { experimental = { serverStatusNotification = true } }),
    handlers = { ["experimental/serverStatus"] = function(_, r) _G.st = r end } }, { bufnr = b })
end
local client = vim.lsp.get_client_by_id(id)
vim.wait(60000, function() return _G.st and _G.st.quiescent end, 100)
local function locate(f, needle, nth)
  local seen = 0
  for i, l in ipairs(vim.api.nvim_buf_get_lines(bufs[f], 0, -1, false)) do
    local s = l:find(needle, 1, true)
    while s do
      seen = seen + 1
      if seen == (nth or 1) then return i - 1, s - 1 end
      s = l:find(needle, s + 1, true)
    end
  end
end
local function req(method, f, line, col)
  local p = { textDocument = { uri = vim.uri_from_bufnr(bufs[f]) }, position = { line = line, character = col }, context = { includeDeclaration = false } }
  local r = vim.lsp.buf_request_sync(bufs[f], method, p, 20000)
  local items = {}
  for _, x in pairs(r or {}) do for _, it in ipairs(x.result or {}) do items[#items + 1] = it end end
  table.sort(items, function(a, b)
    if (a.uri or "") ~= (b.uri or "") then return (a.uri or "") < (b.uri or "") end
    return a.range.start.line < b.range.start.line or (a.range.start.line == b.range.start.line and a.range.start.character < b.range.start.character)
  end)
  return items, p
end
local ts_cache = {}
local function ts_class(path, row, col)
  if not ts_cache[path] then
    local src = table.concat(vim.fn.readfile(path), "\n") .. "\n"
    ts_cache[path] = { src = src, root = vim.treesitter.get_string_parser(src, "rust"):parse()[1]:root() }
  end
  local c = ts_cache[path]
  return classify(c.root, c.src, "rust", row, col)
end
local default = '[["src/money.rs","pub struct Money",1,11],["src/money.rs","pub cents",1,4]]'
for _, q in ipairs(vim.json.decode(os.getenv("QUERIES") or default)) do
  local line, col = locate(q[1], q[2], q[3])
  col = col + (q[4] or 0)
  -- wait until references are stable
  local last, stable, items = -1, 0, nil
  vim.wait(60000, function()
    items = req("textDocument/references", q[1], line, col)
    stable = (#items == last and #items > 0) and stable + 1 or 0
    last = #items
    return stable >= 2
  end, 500)
  out(("\n## references %s:%d:%d"):format(q[1], line + 1, col + 1))
  for _, it in ipairs(items) do
    local path = vim.uri_to_fname(it.uri)
    local rel = path:sub(#root + 2)
    local s = it.range.start
    local text = (vim.fn.readfile(path)[s.line + 1] or "")
    out(("  %s:%d:%d %-24s %q"):format(rel, s.line + 1, s.character + 1, tostring(ts_class(path, s.line, s.character)), vim.trim(text)))
  end
  local hl = req("textDocument/documentHighlight", q[1], line, col)
  out("  highlights in " .. q[1] .. ":")
  for _, it in ipairs(hl) do out(("    %d:%d kind=%s"):format(it.range.start.line + 1, it.range.start.character + 1, tostring(it.kind))) end
end
client:stop(true)
