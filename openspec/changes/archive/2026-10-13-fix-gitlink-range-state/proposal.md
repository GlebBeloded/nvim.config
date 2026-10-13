## Why
`:Gitlink` with a range (`lua/gleb/git/gitlink.lua`, fix-gitlink-range) restores the cursor and Normal mode, but `:3,5Gitlink` from Normal mode overwrites the `'<`/`'>` marks (so `gv` reselects 3-5), and an error inside gitlinker leaves the user in linewise Visual mode because the call has no `pcall`. The test asserts the mode but not the restored cursor, and does not cover `:3,5Gitlink` from Normal mode; its `git()` helper lacks LuaCATS.

Kind: bug

## What Changes
- Save and restore the `'<`/`'>` marks around the ranged call; restore cursor and mode also when gitlinker errors (pcall, re-raise after restoring).
- Test: assert the cursor is back, add a `:3,5Gitlink` from Normal mode case, annotate the `git()` helper.

## Capabilities
- `git`: Preserve editor range state around `:Gitlink` and restore it before propagating failures.

## Impact
- Code: `lua/gleb/git/gitlink.lua`, `tests/integration/git/test_gitlink.lua`.
- Plugins: none. Core keymaps: unchanged.
- Out of scope: other gitlinker options.
