## Why
Every Neovim starts its own language servers (`lua/gleb/lsp/config/init.lua:43-49`, default lspconfig `cmd`), and each new server loads the whole workspace before it answers. Measured from `:edit` to the first `textDocument/documentSymbol` answer (root cause: `artifacts/runs/b1c94bd6-…/root-cause.md`): lua_ls in this checkout 2.8–3.2 s, gopls in a 542-package module 1.5–4.3 s, basedpyright 1.1–2.8 s, vtsls 0.7–0.9 s. The accepted bounds are 2.5 s for lua_ls in this config and 1 s for the small-project fixtures of gopls, basedpyright, and vtsls.

Kind: bug
Adopt: loop/fix-lsp-readiness-20261014-004515

## What Changes
- Add a `Language server readiness` requirement to `lsp`: lua_ls answers its first request within 2.5 s of `:edit`; gopls, basedpyright, and vtsls answer within 1 s. Each server gets a controlled scenario.
- lua_ls: in this checkout, readiness is held back by `workspace.library` in `.luarc.jsonc` (`$VIMRUNTIME`, luv, `.tests/deps/mini.nvim`), which LuaLS indexes before it answers. On a copy of the repo, an empty library brought readiness from 1.7 s to 0.74 s. `make types` keeps the full library through its own config file. In the editor, Neovim API types load lazily, only for the modules a file actually requires (see Open question 1).
- gopls, basedpyright, vtsls: add regression scenarios on small fixture projects. These already pass (gopls 0.25–0.46 s, basedpyright 0.5–0.8 s).
- Test harness: full-config children find the mason-installed servers (`<NVIM_TEST_DATA_DIR>/mason/bin`). Readiness runs in a dedicated serial check layer after the parallel layers so contention cannot distort the fixed bounds.

## Capabilities
### Modified Capabilities
- `lsp`: new requirement `Language server readiness`. Diagnostic sign requirements are unchanged.

## Impact
- Code: `.luarc.jsonc`, `tests/types.sh` (+ a types-only LuaLS config), `lua/gleb/lsp/config/lua/`, `tests/helpers.lua`, new `tests/integration/lsp/test_readiness.lua` with fixtures, `docs/testing.md` (mason link, `make types` config).
- Plugins: no dependency is added, removed, or upgraded. The existing `folke/lazydev.nvim` integration remains enabled so lua_ls exposes Neovim API types lazily.
- Core keymaps: unchanged.
- Out of scope: gopls readiness in large modules (open question 2); terraform, yaml, json, html, css and bash servers (not measured); rust-analyzer (owned by rustaceanvim); shared or daemon servers (`gopls -remote=auto` was measured and does not reuse the package load).

## Open questions for the user
1. **lua_ls library:** may the config add `folke/lazydev.nvim`, so the editor loads Neovim types lazily while `make types` keeps checking against the full `$VIMRUNTIME`? Without it, the editor lists only the libraries this repo needs, and LSP features on `vim.*` lose types until that list is extended by hand.
2. **gopls in large modules:** gopls loads the full `go list -deps` closure of the module before it answers. In `svc/lavanderia` that is 1.2 s inside gopls (2.1 s for `go list` alone), with the gopls disk cache warm. No gopls setting tested got under 1 s: a shared `-remote=auto` daemon gave 2.4–5.3 s, and a narrowed `root_dir` with `expandWorkspaceToModule = false` gave 1.7–2.4 s. The upstream issue golang/go#69523 is open. Options:
   - **(A, recommended):** keep the 1 s target for small modules only, and track large modules upstream.
   - **(B):** start the servers for the cwd's project during startup, before any file opens, so the load overlaps with startup. This does not help a session restore, because the buffer opens during `VimEnter`, and it is new behaviour.
   - **(C):** drop the 1 s target for gopls.

## Decision (user, 2026-10-13)
1. lua_ls library: add `folke/lazydev.nvim`; `make types` keeps the full `$VIMRUNTIME` library.
2. gopls: option A — the 1 s target applies to small modules (fixtures); large modules are tracked upstream (golang/go#69523), out of scope.

## Decision (user, 2026-10-14)
3. lua_ls readiness bound is 2.5 s with lazydev kept (option A); gopls, basedpyright and vtsls keep 1 s. Readiness cases run in their own check layer alone after all other layers (like `+smoke-startup`), not inside `make test`.

## Rejected run
Run on `loop/fix-lsp-readiness-20261014-004515` was rejected by the judge:
- fix loop exhausted (3 attempts) with gates still red: tests,review_skipped
