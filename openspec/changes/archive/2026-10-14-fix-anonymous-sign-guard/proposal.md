## Why
`git: Added line has no competing hunk sign` (find it with `rg -n 'no competing hunk sign' tests`) walks `nvim_get_namespaces()`, which skips anonymous namespaces, so a foreign sign from `nvim_create_namespace("")` would pass. Found by review of fix-hunk-sign-guard (fc6a749), approved without a fix.

Kind: bug

## What Changes
- Query sign extmarks on line 2 from all namespaces (`nvim_buf_get_extmarks(0, -1, …, { details = true, type = "sign" })`) and assert every one belongs to a gitsigns namespace id.
- Task 1.1 shows the tightened assertion failing once by placing a sign from an anonymous namespace in the test, then removes that.

## Capabilities
### Modified Capabilities
None. `skip_specs: true`.

## Impact
- Code: the git integration test file holding that case.
- Plugins: none. Core keymaps: unchanged.
