-- Shared driver: start a server, attach buffers, run references/documentHighlight queries.
local M = {}

local function print(...) io.stdout:write(table.concat({ ... }, ' '), '\n'); io.stdout:flush() end

local cache = {}
local function lines_of(path)
  if not cache[path] then cache[path] = vim.fn.readfile(path) end
  return cache[path]
end

local function rel(root, path)
  return (path:sub(1, #root) == root) and path:sub(#root + 2) or path
end

--- Locate (0-based line, 0-based col) of the nth occurrence of `find` plus offset.
local function locate(path, find, nth, offset)
  local seen = 0
  for i, l in ipairs(lines_of(path)) do
    local init = 1
    while true do
      local s = l:find(find, init, true)
      if not s then break end
      seen = seen + 1
      if seen == (nth or 1) then return i - 1, s - 1 + (offset or 0) end
      init = s + 1
    end
  end
  error('not found: ' .. find)
end

local function range_text(path, r)
  local l = lines_of(path)[r.start.line + 1] or ''
  if r['end'].line ~= r.start.line then
    return l:sub(r.start.character + 1) .. ' ...(multiline to ' .. r['end'].line .. ')'
  end
  return l:sub(r.start.character + 1, r['end'].character)
end

local function extras(item)
  local out = {}
  for k, v in pairs(item) do
    if k ~= 'uri' and k ~= 'range' then out[#out + 1] = k .. '=' .. vim.inspect(v, { newline = '' }) end
  end
  return table.concat(out, ' ')
end

local function flatten(resp)
  local out = {}
  for _, r in pairs(resp or {}) do
    if r.err then print('  ERR ' .. vim.inspect(r.err)) end
    for _, item in ipairs(r.result or {}) do out[#out + 1] = item end
  end
  table.sort(out, function(a, b)
    if (a.uri or '') ~= (b.uri or '') then return (a.uri or '') < (b.uri or '') end
    if a.range.start.line ~= b.range.start.line then return a.range.start.line < b.range.start.line end
    return a.range.start.character < b.range.start.character
  end)
  return out
end

function M.setup(opts)
  local bufs = {}
  for _, f in ipairs(opts.files) do
    local path = opts.root .. '/' .. f
    local b = vim.fn.bufadd(path)
    vim.fn.bufload(b)
    vim.bo[b].filetype = opts.filetype
    bufs[f] = b
  end
  local id
  for _, b in pairs(bufs) do
    id = vim.lsp.start({ name = opts.name, cmd = opts.cmd, root_dir = opts.root, settings = opts.settings,
        capabilities = opts.capabilities, handlers = opts.handlers },
      { bufnr = b })
  end
  local client = vim.lsp.get_client_by_id(id)
  vim.wait(30000, function() return client.initialized end, 100)
  M.print = print
  print(('server=%s initialized=%s encoding=%s'):format(opts.name, tostring(client.initialized),
    client.offset_encoding))
  return { root = opts.root, bufs = bufs, client = client }
end

local function params(ctx, q)
  local path = ctx.root .. '/' .. q.file
  local line, col = locate(path, q.find, q.nth, q.offset)
  return {
    textDocument = { uri = vim.uri_from_fname(path) },
    position = { line = line, character = col },
    context = { includeDeclaration = true },
  }, line, col
end

function M.raw(ctx, method, q)
  local p = params(ctx, q)
  return flatten(vim.lsp.buf_request_sync(ctx.bufs[q.file], method, p, 20000))
end

function M.query(ctx, method, q)
  local p, line, col = params(ctx, q)
  local path = ctx.root .. '/' .. q.file
  local word = lines_of(path)[line + 1]:sub(col + 1):match('^[%w_]*')
  print(('\n## %s [%s] @ %s:%d:%d on %q'):format(q.label, method, q.file, line, col, word))
  local items = flatten(vim.lsp.buf_request_sync(ctx.bufs[q.file], method, p, 20000))
  for _, it in ipairs(items) do
    local uri = it.uri or p.textDocument.uri
    local fpath = vim.uri_to_fname(uri)
    local r = it.range
    local src = vim.trim(lines_of(fpath)[r.start.line + 1] or '')
    print(('  %s %d:%d-%d:%d text=%q %s  | %s'):format(rel(ctx.root, fpath), r.start.line, r.start.character,
      r['end'].line, r['end'].character, range_text(fpath, r), extras(it), src))
  end
  if #items == 0 then print('  (none)') end
end

return M
