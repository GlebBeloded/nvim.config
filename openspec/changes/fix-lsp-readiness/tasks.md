## 1. Align the adopted LuaLS readiness case
Scenarios: `lsp: lua_ls ready within 2.5 s in this config`
- [x] 1.1 Run the existing test in `tests/integration/lsp/test_readiness.lua` against the renamed scenario and see `make trace` fail because it still says `lua_ls ready within 1 s in this config`
- [x] 1.2 Rename the test to `lsp: lua_ls ready within 2.5 s in this config`, retain its fixed 2500 ms bound, and correct the `make types` table entry in `docs/testing.md` to name `tests/luarc.types.jsonc`
- [x] 1.3 Run `make test FILE=tests/integration/lsp/test_readiness.lua CASE="lua_ls ready within 2.5 s in this config"` and see it pass
- [x] 1.4 Run the load-sensitive readiness file serially after the parallel shards so host load does not skew its fixed bounds
- [ ] 1.5 Run `make check` and see the full gate, including traceability, pass
