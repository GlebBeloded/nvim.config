## Why
The 2026-10-13 consistency audit (branch `loop/fix-20261013-091922`, never merged) found three bugs still on `auto`:
- `lua/gleb/telescope.lua:20` maps `["C-j>"]` (missing `<`), so `<C-j>` never moves the Telescope selection.
- `lua/gleb/run/init.lua:10` tests `vim.fn.filereadable("Cargo.lock")` as a Lua truthy value; `0` is truthy in Lua, so the Cargo branch always wins over later checks.
- `lua/gleb/select/code_action.lua:70` passes `keymap = code_action.keymap`, a field that is never set, so the menu gets nil keymaps.
- `tests/quick.sh:50` routes `lua/gleb/lualine.lua` to `statusline`, but that file no longer exists (removed in 2f7960b; the route came back with the fix-port-synthetic-repo-e2e merge).

Kind: bug

## What Changes
- Correct the Telescope insert-mode `<C-j>` mapping so it moves to the next selection.
- Make `:Run` choose Cargo only when `Cargo.lock` is readable, leaving directories with neither supported marker untouched.
- Give the code-action menu its declared default keymap, including `<Space>` to submit.
- Remove the stale `lua/gleb/lualine.lua` route from `tests/quick.sh` and guard literal quick routes against missing files.
- Fix each bug with a failing test first (one case each).
- Reference: the audit branch's `tests/unit/loop/test_conventions.lua` and proposals (read with `git show loop/fix-20261013-091922:<path>`); port nothing else from it.

## Capabilities
### New Capabilities
- `telescope`: Telescope prompt-local navigation mappings.
- `run`: project-marker dispatch for `:Run`.
- `select`: code-action picker menu mappings.

### Modified Capabilities
- `loop`: quick-test routes reference files that exist.

## Impact
- Code: `tests/quick.sh`, `lua/gleb/telescope.lua`, `lua/gleb/run/init.lua`, `lua/gleb/select/code_action.lua`, their tests.
- Plugins: none added, removed or upgraded.
- Core keymaps: unchanged (the Telescope and code-action mappings are picker-local).
- Out of scope: other Telescope mappings, terminal delivery of Ctrl+J, `git_root()`, adding a new `:Run` fallback, the code-action picker layout, and other quick-test routes.
