## 1. Restore reachable Diffview conflict choices
Scenarios: `git: Cmd+O chooses ours`, `git: Cmd+I chooses theirs`, `git: Cmd+D chooses base`, `git: Cmd+A chooses all`
- [x] 1.1 Update the four existing scenario tests in `tests/integration/git/test_diffview.lua` to press `<leader>co`, `<leader>ct`, `<leader>cb`, and `<leader>ca`; run `make test FILE=tests/integration/git/test_diffview.lua CASE="chooses"` and see them fail
- [ ] 1.2 Remove the four `<D-*>` conflict overrides from `lua/gleb/git/diffview.lua` so Diffview's default conflict mappings apply
- [ ] 1.3 Run `make test FILE=tests/integration/git/test_diffview.lua CASE="chooses"` and see all four scenarios pass

## Blocked

Probe output: `literal_leader_hit=false`, `actual_leader_hit=false` (the second input followed the unresolved literal input).

- Attempt 1 removed the four `<D-*>` overrides; all four scenarios still failed because `nvim_input()` sent literal `<leader>` notation instead of the configured leader key.
- Attempt 2 expanded `<leader>` before input; all four scenarios errored with `Wrong number of arguments: expecting 1 but got 2` because `string.gsub()` returned both the expanded string and replacement count to the RPC call.
