## 1. Restore reachable Diffview conflict choices
Scenarios: `git: Cmd+O chooses ours`, `git: Cmd+I chooses theirs`, `git: Cmd+D chooses base`, `git: Cmd+A chooses all`
- [x] 1.1 Update the four existing scenario tests in `tests/integration/git/test_diffview.lua` to press `<leader>co`, `<leader>ct`, `<leader>cb`, and `<leader>ca`; run `make test FILE=tests/integration/git/test_diffview.lua CASE="chooses"` and see them fail
- [x] 1.2 Remove the four `<D-*>` conflict overrides from `lua/gleb/git/diffview.lua` so Diffview's default conflict mappings apply
- [x] 1.3 Run `make test FILE=tests/integration/git/test_diffview.lua CASE="chooses"` and see all four scenarios pass
