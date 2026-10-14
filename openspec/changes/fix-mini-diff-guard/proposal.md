## Why
The guard that mini.diff stays removed (`tests/integration/git/test_git.lua` ~241-242, from fix-duplicate-gitsigns-case) reads `MiniDiff*` sign extmarks the moment the gitsigns sign appears. mini.diff draws after its own debounce, so if the plugin came back the case could pass before its signs exist. The scenario it guards says "no other plugin" adds a sign, but only MiniDiff is checked.

Kind: bug

## What Changes
- Make the guard deterministic: assert mini.diff is neither loaded nor registered with lazy.nvim (`package.loaded["mini.diff"]`, lazy's plugin table), in addition to the current sign check.
- Reword the scenario's THEN to name what is checked (gitsigns is the only hunk sign source; mini.diff is not installed), without loosening it.

## Capabilities
### Modified Capabilities
- `git`: the guard scenario's wording only.

## Impact
- Code: `tests/integration/git/test_git.lua`.
- Plugins: none. Core keymaps: unchanged.
- Out of scope: changing hunk-sign providers, gitsigns configuration, or plugin dependencies.
