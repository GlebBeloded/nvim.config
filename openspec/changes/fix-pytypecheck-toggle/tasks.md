## 1. Restore basedpyright after a type-check toggle
Scenarios: `lsp: Type-check toggle reattaches every Python buffer without reloading`
- [x] 1.1 Write the test `lsp: Type-check toggle reattaches every Python buffer without reloading` in tests/integration/lsp/test_typecheck.lua and see it fail
- [x] 1.2 Restart basedpyright through Neovim's enable API so every loaded Python buffer reattaches without reload, and remove the dead JSON `setup.commands` block
- [x] 1.3 Run `make test FILE=tests/integration/lsp/test_typecheck.lua CASE="Type-check toggle reattaches every Python buffer without reloading"` and see it pass
