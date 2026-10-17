local here = vim.fn.fnamemodify(arg[0], ':p:h')
local C = dofile(here .. '/common.lua')
local ctx = C.setup({
  name = 'basedpyright', filetype = 'python', root = here .. '/py',
  cmd = { 'basedpyright-langserver', '--stdio' },
  files = { 'main.py', 'pkg/mod.py', 'pkg/__init__.py' },
  settings = { basedpyright = { analysis = { diagnosticMode = 'workspace' } } },
})
vim.wait(20000, function()
  return #C.raw(ctx, 'textDocument/references', { file = 'pkg/mod.py', find = 'Thing' }) > 0
end, 500)
local R = 'textDocument/references'
local qs = {
  { label = 'class Thing (decl)', file = 'pkg/mod.py', find = 'class Thing', offset = 6 },
  { label = 'Thing.method', file = 'pkg/mod.py', find = 'def method', offset = 4 },
  { label = 'def f', file = 'pkg/mod.py', find = 'def f(', offset = 4 },
  { label = 'param name of f', file = 'pkg/mod.py', find = 'name: int', offset = 0 },
  { label = 'kwarg name=1 at call', file = 'main.py', find = 'name=1', offset = 0 },
  { label = 'class Base', file = 'pkg/mod.py', find = 'class Base', offset = 6 },
  { label = 'def dec', file = 'pkg/mod.py', find = 'def dec(', offset = 4 },
  { label = 'def deco2', file = 'pkg/mod.py', find = 'def deco2', offset = 4 },
  { label = 'class Err', file = 'pkg/mod.py', find = 'class Err', offset = 6 },
  { label = 'module mod via import pkg.mod', file = 'main.py', find = 'import pkg.mod', nth = 1, offset = 11 },
  { label = 'package pkg via import pkg.mod', file = 'main.py', find = 'import pkg.mod', nth = 1, offset = 7 },
  { label = 'mod in pkg.mod.Thing', file = 'main.py', find = 'pkg.mod.Thing', offset = 4 },
  { label = 'pkg in pkg.mod.Thing', file = 'main.py', find = 'pkg.mod.Thing', offset = 0 },
  { label = 'alias m', file = 'main.py', find = 'as m', offset = 3 },
  { label = 'type alias Al', file = 'main.py', find = 'type Al', offset = 5 },
  { label = 'local obj', file = 'main.py', find = 'obj =', offset = 0 },
}
for _, q in ipairs(qs) do C.query(ctx, R, q) end
local H = 'textDocument/documentHighlight'
for _, q in ipairs({
  { label = 'hl Thing in main', file = 'main.py', find = 'm.Thing()', offset = 2 },
  { label = 'hl alias m', file = 'main.py', find = 'as m', offset = 3 },
  { label = 'hl obj', file = 'main.py', find = 'obj =', offset = 0 },
}) do C.query(ctx, H, q) end
ctx.client:stop(true)
