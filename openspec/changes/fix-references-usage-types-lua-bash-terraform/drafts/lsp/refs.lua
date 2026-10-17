-- usage: nvim --clean --headless -l refs.lua <spec.lua>
-- spec returns { name, cmd, root, filetype, open = {files}, queries = { {label, file, line, col, highlight=bool} } }
local spec = dofile(arg[1])
local root = spec.root

local function bufnr_for(path)
  local b = vim.fn.bufadd(path)
  vim.fn.bufload(b)
  vim.bo[b].filetype = spec.filetype
  return b
end

local client_id
for _, f in ipairs(spec.open) do
  local b = bufnr_for(root .. "/" .. f)
  local id = vim.lsp.start({
    name = spec.name,
    cmd = spec.cmd,
    root_dir = root,
    settings = spec.settings,
    init_options = spec.init_options,
  }, { bufnr = b })
  client_id = client_id or id
end
local client = assert(vim.lsp.get_client_by_id(client_id))
assert(vim.wait(15000, function() return client.initialized end, 100), "not initialized")
print(("[%s] initialized"):format(spec.name))

local function line_of(uri, l)
  local fname = vim.uri_to_fname(uri)
  local lines = vim.fn.readfile(fname)
  return lines[l + 1] or ""
end

local function fmt_loc(uri, r)
  local s, e = r.start, r["end"]
  local src = line_of(uri, s.line)
  local text
  if s.line == e.line then
    text = src:sub(s.character + 1, e.character)
  else
    text = src:sub(s.character + 1) .. "…"
  end
  return ("  %s %d:%d-%d:%d <%s>   | %s"):format(vim.fs.relpath(root, vim.uri_to_fname(uri)) or uri, s.line, s.character, e.line, e.character, text, src)
end

local function sig(res)
  local t = {}
  for _, l in ipairs(res or {}) do
    local r = l.range
    t[#t + 1] = l.uri .. r.start.line .. ":" .. r.start.character .. "-" .. r["end"].line .. ":" .. r["end"].character
  end
  table.sort(t)
  return table.concat(t, ";")
end

local function request(method, params, b)
  local resp = client:request_sync(method, params, 10000, b)
  if not resp then return nil, "timeout" end
  if resp.err then return nil, vim.inspect(resp.err) end
  return resp.result
end

local function stable_refs(params, b)
  local last, same, res, err = nil, 0, nil, nil
  local deadline = vim.uv.now() + (spec.wait or 30000)
  repeat
    res, err = request("textDocument/references", params, b)
    local s = sig(res)
    if s == last and s ~= "" then same = same + 1 else same = 0 end
    last = s
    if same >= (spec.stable or 2) then break end
    vim.wait(1000)
  until vim.uv.now() > deadline
  return res, err
end

local kinds = { [1] = "Text", [2] = "Read", [3] = "Write" }

for _, q in ipairs(spec.queries) do
  local path = root .. "/" .. q.file
  local b = bufnr_for(path)
  if not vim.lsp.buf_is_attached(b, client_id) then vim.lsp.buf_attach_client(b, client_id) end
  local src = vim.api.nvim_buf_get_lines(b, q.line, q.line + 1, false)[1] or ""
  if q.find then
    local s = assert(src:find(q.find, 1, true), "find failed: " .. q.find)
    q.col = s - 1 + (q.off or 0)
  end
  print(("\n== %s  @ %s %d:%d  [%s]  | %s"):format(q.label, q.file, q.line, q.col, src:sub(q.col + 1, q.col + 12), src))
  local params = {
    textDocument = { uri = vim.uri_from_fname(path) },
    position = { line = q.line, character = q.col },
    context = { includeDeclaration = true },
  }
  local res, err = stable_refs(params, b)
  if err then print("  ERR " .. err) end
  if not res or #res == 0 then print("  (no references)") end
  table.sort(res or {}, function(a, c)
    if a.uri ~= c.uri then return a.uri < c.uri end
    if a.range.start.line ~= c.range.start.line then return a.range.start.line < c.range.start.line end
    return a.range.start.character < c.range.start.character
  end)
  for _, l in ipairs(res or {}) do print(fmt_loc(l.uri, l.range)) end
  if q.highlight then
    local hl, herr = request("textDocument/documentHighlight", params, b)
    print("  -- documentHighlight" .. (herr and (" ERR " .. herr) or ""))
    for _, h in ipairs(hl or {}) do
      print(fmt_loc(params.textDocument.uri, h.range) .. "  kind=" .. tostring(h.kind and kinds[h.kind] or h.kind))
    end
  end
end

client:stop()
vim.wait(2000, function() return client:is_stopped() end)
