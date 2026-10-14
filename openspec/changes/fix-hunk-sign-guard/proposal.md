## Why
`openspec/specs/git/spec.md` (Added line scenario) says gitsigns is the only configured hunk-sign source on the added line, but `tests/integration/git/test_git.lua` (`git: Added line shows bar sign`) only checks that no `MiniDiff*` sign exists there. Another plugin drawing a hunk sign on that line would pass.

Kind: bug

## What Changes
- In that case, assert that every sign extmark on line 2 belongs to a `gitsigns_*` namespace (keep the existing `┃` and mini.diff checks).
- Locate code with `rg -n`, not line numbers.

## Capabilities
### Modified Capabilities
None. `skip_specs: true`.

## Impact
- Code: `tests/integration/git/test_git.lua`.
- Plugins: none. Core keymaps: unchanged.
