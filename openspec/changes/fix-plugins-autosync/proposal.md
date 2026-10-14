## Why
`lua/gleb/plugins/init.lua` (~25-28) runs `:Lazy sync` when any file named `plugins.lua` is written: that updates every plugin and rewrites the pinned `lazy-lock.json`, contradicting the pin policy (`make update`).
Found by the final audit of auto (2026-10-14).

Kind: bug

## Evidence
- `lua/gleb/plugins/init.lua:19` defines a callback that sources the written file, and
  `lua/gleb/plugins/init.lua:21` unconditionally executes `Lazy sync`.
- `lua/gleb/plugins/init.lua:25` registers that callback for every `BufWritePost` whose basename matches
  `plugins.lua`; it does not restrict the match to this config's plugin specification.
- `docs/workflow.md:82` requires plugin updates to happen only on demand, one plugin per update run.
- `/Users/hlebbeladzed/.local/share/nvim/lazy/lazy.nvim/lua/lazy/core/config.lua:188` enables lazy.nvim's
  config change detection by default, and `lua/lazy/manage/reloader.lua:44` tracks loaded spec modules.

The root cause is the config-owned basename autocmd: an ordinary write is turned into an unconditional
full dependency sync, bypassing the repository's explicit update workflow and potentially rewriting
`lazy-lock.json`.

## What Changes
- Remove the autocmd (lazy.nvim's change detection covers spec reloads); test: writing a `plugins.lua` buffer runs no Lazy command.
- Task 1.1 shows the new assertion failing before the fix.

## Capabilities
### Added Capabilities
- `plugins`: writing the plugin specification does not trigger a dependency sync.

## Impact
- Code: `lua/gleb/plugins/init.lua` and a focused integration test.
- Plugins: none added or upgraded.
- Core keymaps: unchanged.
- Out of scope: changing lazy.nvim's built-in specification reload behaviour or the explicit `make update`
  workflow.
