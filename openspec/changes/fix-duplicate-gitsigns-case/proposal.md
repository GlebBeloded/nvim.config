## Why
`make trace` is red on `auto`: `git: Added line shows bar sign` exists in both `tests/integration/git/test_git.lua:222` and `tests/integration/git/test_gitsigns.lua:29` (the latter came with remove-redundant-plugins, whose gate ran before the former landed). The `test_gitsigns.lua` copy is weaker: it does not wait for the sign and `vim.trim(nil)` throws an unclear error when no mark exists, and neither copy would catch mini.diff coming back.

Kind: bug

## What Changes
- Keep one case named `git: Added line shows bar sign` (the waiting one in `test_git.lua`) and remove the other; fold in an assertion that gitsigns is the only hunk sign source (no `MiniDiff*` namespace), so the removal stays guarded.
- `make trace` reports 0 duplicates.

## Capabilities
### Modified Capabilities
None. `skip_specs: true`.

## Impact
- Code: `tests/integration/git/test_git.lua`, `tests/integration/git/test_gitsigns.lua`.
- Plugins: none. Core keymaps: unchanged.
