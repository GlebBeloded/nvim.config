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
vim.wait(60000, function() return _G.ra_status and _G.ra_status.quiescent end, 200)
for i = 1, 4 do
  vim.wait(3000)
  local items = C.raw(ctx, 'textDocument/references', { file = 'src/lib.rs', find = 'pub struct Thing', offset = 11 })
  C.print(i, #items, vim.json.encode(vim.tbl_map(function(x) return x.range.start end, items)))
end
ctx.client:stop(true)
