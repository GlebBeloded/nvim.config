local here = vim.fn.fnamemodify(arg[0], ':p:h')
local C = dofile(here .. '/common.lua')
local ctx = C.setup({
  name = 'rust-analyzer', filetype = 'rust', root = here .. '/rs/' .. (os.getenv('RSDIR') or 'fixture'),
  cmd = { vim.fn.expand('~/.local/share/nvim/mason/bin/rust-analyzer') },
  files = { 'src/lib.rs' },
  capabilities = vim.tbl_deep_extend('force', vim.lsp.protocol.make_client_capabilities(),
    { experimental = { serverStatusNotification = true } }),
  handlers = { ['experimental/serverStatus'] = function(_, r) _G.ra_status = r end },
})
local F = 'src/lib.rs'
local t0 = vim.uv.now()
local last, stable = -1, 0
local ok = vim.wait(60000, function()
  if not (_G.ra_status and _G.ra_status.quiescent) then return false end
  local n = #C.raw(ctx, 'textDocument/references', { file = F, find = 'pub struct Thing', offset = 11 })
  stable = (n == last and n > 1) and stable + 1 or 0
  last = n
  return stable >= 2
end, 1000)
C.print(('rust-analyzer ready=%s after %dms status=%s refs(Thing)=%d'):format(tostring(ok), vim.uv.now() - t0,
  vim.inspect(_G.ra_status, { newline = '' }), last))
local R = 'textDocument/references'
local qs = {
  { label = 'struct Thing (decl)', find = 'pub struct Thing', offset = 11 },
  { label = 'field `field` (decl)', find = 'pub field', offset = 4 },
  { label = 'local `field` (let field = 5)', find = 'let field', offset = 4 },
  { label = 'shorthand `field` in Thing { field }', find = 'Thing { field }', offset = 8 },
  { label = 'fn method', find = 'fn method', offset = 3 },
  { label = 'fn new', find = 'fn new', offset = 3 },
  { label = 'fn foo', find = 'pub fn foo', offset = 7 },
  { label = 'trait Tr', find = 'pub trait Tr', offset = 10 },
  { label = 'alias T2 (use ... as T2)', find = 'as T2', offset = 3 },
  { label = 'enum En', find = 'pub enum En', offset = 9 },
  { label = 'variant V', find = 'V(i32)', offset = 0 },
  { label = 'variant W', find = 'W { x', offset = 0 },
  { label = 'type Num', find = 'pub type Num', offset = 9 },
  { label = 'macro mm', find = 'macro_rules! mm', offset = 13 },
  { label = 'local thing_var', find = 'let thing_var', offset = 4 },
  { label = 'module a', find = 'pub mod a', offset = 8 },
  { label = 'param t', find = 'h(t:', offset = 2 },
  { label = 'Thing from usage a::Thing::new()', find = 'a::Thing::new', offset = 3 },
  { label = 'Thing from usage crate::a::Thing {', find = 'crate::a::Thing {', offset = 10 },
  { label = 'method from usage t.method()', find = 't.method', offset = 2 },
  { label = 'pattern binding x in W { x }', find = 'W { x }', offset = 4 },
}
for _, q in ipairs(qs) do q.file = F; C.query(ctx, R, q) end
local H = 'textDocument/documentHighlight'
for _, q in ipairs({
  { label = 'hl struct Thing', find = 'pub struct Thing', offset = 11 },
  { label = 'hl field', find = 'pub field', offset = 4 },
  { label = 'hl thing_var', find = 'let thing_var', offset = 4 },
  { label = 'hl local field', find = 'let field', offset = 4 },
  { label = 'hl fn foo', find = 'pub fn foo', offset = 7 },
}) do q.file = F; C.query(ctx, H, q) end
ctx.client:stop(true)
