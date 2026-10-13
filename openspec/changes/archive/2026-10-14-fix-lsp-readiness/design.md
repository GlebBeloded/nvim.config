# Design

## Context
See proposal.md, Why. The measurements behind this design were taken with the real config in headless Neovim 0.12.5. Each probe recorded the time from `:edit` to the first successful `documentSymbol` answer. Servers were mason-installed: lua-language-server 3.17.1, gopls 0.21.1.

| Setup | lua_ls ready |
|---|---|
| this worktree as-is | 2.8–3.2 s |
| copy of `lua/`, `init.lua`, `.luarc.jsonc` (no `.tests/`) | 1.65–1.7 s |
| same copy, `"workspace.library": []` | 0.74 s |
| same copy, no `.luarc.jsonc` (lspconfig defaults + `settings.json`) | 1.8 s |

LuaLS reads `.luarc.jsonc` from the workspace root, and its values win over the client `settings`. Therefore the editor config cannot retain the full static-analysis library without paying its indexing cost. `make types` uses a separate `tests/luarc.types.jsonc` so static analysis retains that library.

Test children get a fresh `XDG_DATA_HOME` with `lazy/`, `site/`, and `mason/` linked from `NVIM_TEST_DATA_DIR`. The mason link makes the installed server binaries available to full-config children.

## Goals / Non-Goals
**Goals:** the four readiness scenarios pass in their dedicated serial check layer. `make types` checks against the same libraries as before the config split.

**Non-Goals:** gopls on large modules (proposal, open question 2). Changing how servers are spawned (shared daemons, start before any file opens). Readiness of servers without a scenario.

## Decisions
1. **Split the LuaLS config:** `.luarc.jsonc` (editor) keeps runtime, diagnostics, and `ignoreDir`, with no `workspace.library`. `tests/luarc.types.jsonc` adds `workspace.library` and is the `--configpath` and cache-key input in `tests/types.sh`.
   - Rejected: drop the library and accept untyped `vim.*` in `make types`. That weakens the Static layer.
   - Rejected: keep the library and narrow it to a few `$VIMRUNTIME/lua/vim/*` files. That is fragile, and its speed was not measured.
2. **Editor types for `vim.*`:** use the existing `folke/lazydev.nvim` integration to add library paths lazily per required module while keeping the types gate independent.
3. **Readiness probe in tests:** a helper starts the full-config child with cwd at the fixture or checkout and records `vim.uv.hrtime()` before `:edit`. It polls `vim.lsp.get_clients({ bufnr = 0, name = … })` and sends `textDocument/documentSymbol`, retrying error answers while the server loads. Elapsed time is measured to the first non-error answer and checked once against the server's fixed bound.
4. **Warm-up start:** each readiness case first starts and stops the server once in a throwaway child. The spec measures warm caches, and a cold first start (seen at 1.8 s for basedpyright) depends on the OS cache, not on the config.
5. **Mason in children:** `tests/helpers.lua` links `<NVIM_TEST_DATA_DIR>/mason` like `lazy/`. A readiness case whose server binary is missing fails, naming the binary. It does not skip: skipping would hide the regression.
6. **Fixtures:** Go, Python, and TypeScript fixtures are written to a temp dir by the test, not committed (no `go.sum` or `node_modules`). The Go fixture has no external imports, so gopls never hits the network.
7. **Serial timing layer:** readiness is excluded from the parallel integration layer and runs alone after the other check layers. Fixed bounds do not scale with host load, and over-bound samples are not retried.

## Risks / Trade-offs
- [Timing checks exceed a fixed bound even in the serial layer] → Escalate the measured failure; do not retry the sample, scale the bound, or hide the regression.
- [gopls needs `go` on `PATH` and a warm module cache] → The fixture uses only the standard library. `go` comes from the user's environment, like the other toolchain tools.
- [The editor `.luarc.jsonc` loses its full library] → lazydev supplies editor metadata lazily, while `make types` retains the complete static-analysis library.
- [A lua_ls update regresses load time] → The lua_ls scenario catches it.
