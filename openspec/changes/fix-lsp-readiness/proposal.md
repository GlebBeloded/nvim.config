## Why
Language servers currently have no readiness contract. Each Neovim starts fresh server processes, and those servers delay requests while loading their workspace. The largest local LuaLS cost is the editor library: removing `workspace.library` from `.luarc.jsonc` reduces the workspace load, but lazydev must retain Neovim runtime metadata so editor hovers stay typed. The adopted implementation measures about 2.1–2.25 s for that combination, while the small Go, Python and TypeScript fixtures remain below 1 s.

Kind: bug
Adopt: loop/fix-20261013-125627

## What Changes
- Define fixed, warm-cache readiness bounds: 2500 ms for lua_ls in this checkout and 1000 ms for gopls, basedpyright and vtsls in small fixture projects.
- Run the load-sensitive readiness cases serially and keep each bound independent of host load.
- Keep the editor `.luarc.jsonc` lean while `make types` uses a dedicated config with the full static library.
- Require lua_ls editor hover to retain a typed `vim.lsp.enable` signature through the existing lazydev.nvim setup.
- Let full-config test children use Mason-installed server binaries.

## Capabilities
### Modified Capabilities
- `lsp`: add language-server readiness and Lua editor type-metadata requirements. Diagnostic sign requirements are unchanged.

## Impact
- Code: `.luarc.jsonc`, `tests/luarc.types.jsonc`, `tests/types.sh`, `tests/helpers.lua`, `tests/integration/lsp/test_readiness.lua`, and `docs/testing.md`.
- Plugins: no dependency is added, removed or upgraded; the existing `folke/lazydev.nvim` setup supplies editor metadata.
- Core keymaps: unchanged.
- Out of scope: gopls readiness in large modules; unmeasured terraform, yaml, json, html, css and bash servers; rust-analyzer (owned by rustaceanvim); shared or daemon servers.

## Decision (user, 2026-10-13)
1. lua_ls library: use `folke/lazydev.nvim`; `make types` keeps the full `$VIMRUNTIME` library.
2. gopls: the 1 s target applies to small modules (fixtures); large modules are tracked upstream in golang/go#69523.
