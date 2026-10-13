## Why
`make trace` is red on `auto`: `git: Added line shows bar sign` exists in both `tests/integration/git/test_git.lua:222` and `tests/integration/git/test_gitsigns.lua:29` (the latter came with remove-redundant-plugins, whose gate ran before the former landed). The `test_gitsigns.lua` copy is weaker: it does not wait for the sign and `vim.trim(nil)` throws an unclear error when no mark exists, and neither copy would catch mini.diff coming back.

Kind: bug

## What Changes
- Keep and harden the existing `git: Added line shows bar sign` case, and give the new `git: Added line has no competing hunk sign` case the distinct responsibility of asserting that no `MiniDiff*` namespace contributes hunk signs.
- `make trace` reports 0 duplicates.

## Capabilities
### Modified Capabilities
- `git`: cover the requirement that no other plugin draws a competing hunk sign with a distinct scenario.

## Impact
- Code: `tests/integration/git/test_git.lua`, `tests/integration/git/test_gitsigns.lua`; spec delta: `openspec/changes/fix-duplicate-gitsigns-case/specs/git/spec.md`.
- Plugins: none. Core keymaps: unchanged.
- Out of scope: changing the gutter sign appearance or gitsigns configuration.
