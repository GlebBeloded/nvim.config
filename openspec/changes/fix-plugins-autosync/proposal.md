## Why
`lua/gleb/plugins/init.lua` (~25-28) runs `:Lazy sync` when any file named `plugins.lua` is written: that updates every plugin and rewrites the pinned `lazy-lock.json`, contradicting the pin policy (`make update`).
Found by the final audit of auto (2026-10-14).

Kind: bug

## Evidence
- Locate code with `rg -n`; the paths above are from the audit (line numbers may drift).

## What Changes
- Remove the autocmd (lazy.nvim's change detection covers spec reloads); test: writing a `plugins.lua` buffer runs no Lazy command.
- Task 1.1 shows the new assertion failing before the fix.

## Capabilities
### Modified Capabilities
- The capability that owns the touched module: a scenario for the fixed behaviour.

## Impact
- Code: the files named above and their tests.
- Plugins: none added or upgraded.
