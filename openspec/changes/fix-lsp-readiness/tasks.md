## 1. Enforce readiness with fixed bounds in an isolated layer
Scenarios: `lsp: lua_ls ready within 2.5 s in this config`, `lsp: gopls ready within 1 s in a small module`, `lsp: basedpyright ready within 1 s in a small project`, `lsp: vtsls ready within 1 s in a small project`
- [x] 1.1 Run the existing tests in `tests/integration/lsp/test_readiness.lua` and see the old 1000 ms lua_ls case fail and its title disagree with `lsp: lua_ls ready within 2.5 s in this config`
- [x] 1.2 Rename the lua_ls case, use its fixed 2500 ms bound, and move the readiness file out of parallel `make test` into a dedicated serial check layer that runs after all other layers without load scaling
- [x] 1.3 Run `make test-readiness FILE=tests/integration/lsp/test_readiness.lua CASE="ready within"` and see all four scenarios pass
- [x] 1.4 Judge one warm readiness sample against the fixed bound; do not retry an over-bound sample
