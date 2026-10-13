## Why
The 2026-10-13 consistency audit (branch `loop/fix-20261013-091922`, never merged) found three bugs still on `auto`:
- `lua/gleb/telescope.lua:20` maps `["C-j>"]` (missing `<`), so `<C-j>` never moves the Telescope selection.
- `lua/gleb/run/init.lua:10` tests `vim.fn.filereadable("Cargo.lock")` as a Lua truthy value; `0` is truthy in Lua, so the Cargo branch always wins over later checks.
- `lua/gleb/select/code_action.lua:70` passes `keymap = code_action.keymap`, a field that is never set, so the menu gets nil keymaps.
- `tests/quick.sh:50` routes `lua/gleb/lualine.lua` to `statusline`, but that file no longer exists (removed in 2f7960b; the route came back with the fix-port-synthetic-repo-e2e merge).

Kind: bug

## What Changes
- Fix each bug with a failing test first (one case each, named after an existing scenario where one covers it; add a scenario in the owning capability's delta only if none does).
- Reference: the audit branch's `tests/unit/loop/test_conventions.lua` and proposals (read with `git show loop/fix-20261013-091922:<path>`); port nothing else from it.

## Capabilities
### Modified Capabilities
Only if a needed scenario is missing (`skip_specs: true` otherwise).

## Impact
- Code: `tests/quick.sh`, `lua/gleb/telescope.lua`, `lua/gleb/run/init.lua`, `lua/gleb/select/code_action.lua`, their tests.
- Plugins: none. Core keymaps: unchanged (the Telescope picker mapping is plugin-local).
