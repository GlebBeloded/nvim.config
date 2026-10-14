## Why
`COMPETING_LINE_2_SIGNS_LUA` in `tests/integration/git/test_git.lua` (find with `rg -n COMPETING_LINE_2_SIGNS_LUA tests`) accepts only namespaces matching `^gitsigns_`, but gitsigns also owns the bare `gitsigns` namespace (`nvim_create_namespace('gitsigns')` in its manager). If gitsigns ever draws a sign there, the guard would wrongly flag it.

Kind: bug

## What Changes
- Accept every gitsigns-owned namespace (`^gitsigns` without the underscore, or the explicit set gitsigns creates) and keep rejecting all others, including anonymous ones.
- Task 1.1 shows the old filter failing once with a sign placed in the bare `gitsigns` namespace in the test, then fixes the filter and removes the probe.

## Capabilities
### Modified Capabilities
None. `skip_specs: true`.

## Impact
- Code: `tests/integration/git/test_git.lua`.
- Plugins: none. Core keymaps: unchanged.
