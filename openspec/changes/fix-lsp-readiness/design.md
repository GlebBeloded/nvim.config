# Design

## Context
See proposal.md, Why. The measurements behind this design were taken with the real config in headless Neovim 0.12.5. Each probe recorded the time from `:edit` to the first successful `documentSymbol` answer. Servers were mason-installed: lua-language-server 3.17.1, gopls 0.21.1.

| Setup | lua_ls ready |
|---|---|
| this worktree as-is | 2.8–3.2 s |
| copy of `lua/`, `init.lua`, `.luarc.jsonc` (no `.tests/`) | 1.65–1.7 s |
| same copy, `"workspace.library": []` | 0.74 s |
| same copy, no `.luarc.jsonc` (lspconfig defaults + `settings.json`) | 1.8 s |

LuaLS reads `.luarc.jsonc` from the workspace root, and its values win over the client `settings`. So this repo's library cost cannot be removed from the client side alone. `make types` already passes `--configpath="$PWD/.luarc.jsonc"` (`tests/types.sh`), so the type check can point at a config file of its own.

Test children get a fresh `XDG_DATA_HOME` with only `lazy/` and `site/` linked (`tests/helpers.lua:47-48`). `mason/` is not linked, so mason.nvim never puts its `bin/` on `PATH` and no mason server can start in a test today.

## Goals / Non-Goals
**Goals:** the four scenarios of the spec delta pass in `make test`. `make types` checks against the same libraries as today.

**Non-Goals:** gopls on large modules (proposal, open question 2). Changing how servers are spawned (shared daemons, start before any file opens). Readiness of servers without a scenario.

## Decisions
1. **Split the LuaLS config:** `.luarc.jsonc` (editor) keeps runtime, diagnostics and `ignoreDir`, with no `workspace.library`. A types-only config (e.g. `tests/luarc.types.jsonc`) adds `workspace.library` and becomes the `--configpath` in `tests/types.sh`. The `tests/types.sh` cache key gains the new file.
   - Rejected: drop the library and accept untyped `vim.*` in `make types`. That weakens the Static layer.
   - Rejected: keep the library and narrow it to a few `$VIMRUNTIME/lua/vim/*` files. That is fragile, and its speed was not measured.
2. **Editor types for `vim.*`:** if the user approves open question 1, use `folke/lazydev.nvim` (`ft = "lua"`), which adds library paths lazily per required module. If not, the editor has no library, and the types gate stays in `make types`. Prefer an existing plugin over custom code (CLAUDE.md).
3. **Readiness probe in tests:** a helper starts the full-config child with cwd at the fixture or checkout and records `vim.uv.hrtime()` before `:edit`. It then polls `vim.lsp.get_clients({ bufnr = 0, name = … })` and sends `textDocument/documentSymbol`, retrying on an error answer (the server is still loading). Elapsed time is measured to the first non-error answer and checked against `< 1000`. It never asserts the symbol count.
4. **Warm-up start:** each readiness case first starts and stops the server once in a throwaway child. The spec measures warm caches, and a cold first start (seen at 1.8 s for basedpyright) depends on the OS cache, not on the config.
5. **Mason in children:** `tests/helpers.lua` links `<NVIM_TEST_DATA_DIR>/mason` like `lazy/`. A readiness case whose server binary is missing fails, naming the binary. It does not skip: skipping would hide the regression.
6. **Fixtures:** Go, Python and TypeScript fixtures are written to a temp dir by the test, not committed (no `go.sum` or `node_modules`). The Go fixture has no external imports, so gopls never hits the network.

## Risks / Trade-offs
- [Timing tests flake under the parallel `make test` load (cores − 2 workers)] → Measure the warm second start only. If they are still flaky, give these cases their own shard via `.tests/timings.json` weight. Never raise the 1000 ms bound.
- [gopls needs `go` on `PATH` and a warm module cache] → The fixture uses only the standard library. `go` comes from the user's environment, like the other toolchain tools.
- [The editor `.luarc.jsonc` loses library types without lazydev] → `make types` remains the gate. Open question 1 decides the editor experience.
- [A lua_ls update regresses load time (upstream issue LuaLS/lua-language-server#3322 reports one for 3.16.x)] → The lua_ls scenario catches it.
