## Why
`make smoke` skips the `neo-tree` and `neotest-golang` healthchecks and ignores a lazy ERROR (`HEALTH_EXCLUDE` / `HEALTH_IGNORE` in `tests/smoke/run.lua:13-27`), so config regressions in those checks go unnoticed. Re-running the probe without those skips (2026-10-12, neo-tree `ebd6676`, neotest-golang `61726ad`) still reports:
- `lazy | ERROR {.../data/nvim/lazy-rocks/hererocks/bin/luarocks} not installed` (lazy itself says no plugin needs luarocks)
- `neo-tree | ERROR config.buffers.renderers: expected ?, got nil`
- `neotest-golang | ERROR Query 'testify/namespace' incompatible: Could not load query file`
- `neotest-golang | ERROR Query 'testify/test_method' incompatible: Could not load query file`

Kind: bug

## What Changes
- lazy: set `rocks = { enabled = false }` in the lazy setup table (`lua/gleb/plugins/init.lua:31-38`), and remove the `hererocks` pattern from `HEALTH_IGNORE`.
- neo-tree: `sources = { "filesystem", "git_status" }` (`file_tree/init.lua:104`) leaves `buffers` unloaded, so neo-tree's `merge_renderers` never fills `buffers.renderers`, but `neo-tree/health/init.lua:302` validates it anyway. Fix in config without enabling the buffers source (adding `buffers` to `sources` would add it to the `>` source cycle): e.g. give `buffers` an explicit `renderers` table (copy of the defaults), or upgrade neo-tree if upstream fixed the check. Then drop `neo-tree` from `HEALTH_EXCLUDE`.
- neotest-golang: with `testify_enabled = true` (`lua/gleb/testing.lua:4`), `neotest-golang/health.lua:169-177` loads `features/testify/queries/go/namespace.scm` and `test_method.scm`, but the pinned plugin ships `suite.scm`, `testify_method.scm`, ... instead (stale paths in the plugin's health check, not our config). Fix by upgrading neotest-golang to a commit whose health check matches its query files (check upstream first); if none exists, keep it excluded with a comment pointing at the upstream issue. Then drop `neotest-golang` from `HEALTH_EXCLUDE`.
- Update the `HEALTH_EXCLUDE` comment so it lists only checks that need external tools.

## Capabilities
### Modified Capabilities
- None (smoke-test tooling and plugin config; no spec'd behaviour changes).

## Impact
- Code: `lua/gleb/plugins/init.lua`, `lua/gleb/file_tree/init.lua`, `tests/smoke/run.lua`, possibly `lazy-lock.json`.
- Plugins: none added or removed; neo-tree.nvim and/or neotest-golang may be upgraded in `lazy-lock.json` if that is the fix.
- Core keymaps: unchanged.
- Out of scope: healthchecks that need external tools (`null-ls` tools, `rustaceanvim`/rust-analyzer, `mason`, `vim.provider`); enabling the neo-tree `buffers` source.
