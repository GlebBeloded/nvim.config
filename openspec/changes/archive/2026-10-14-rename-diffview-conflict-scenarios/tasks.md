## 1. Rename Diffview conflict-choice cases
Scenarios: `git: <leader>co chooses ours`, `git: <leader>ct chooses theirs`, `git: <leader>cb chooses base`, `git: <leader>ca chooses all`
- [x] 1.1 For each scenario above, run `make test FILE=tests/integration/git/test_diffview.lua CASE="<scenario title>"` and see it fail because the renamed case does not exist
- [x] 1.2 Rename the four cases in `tests/integration/git/test_diffview.lua` to match the scenario titles, leaving their bodies and assertions unchanged
- [x] 1.3 Repeat `make test FILE=tests/integration/git/test_diffview.lua CASE="<scenario title>"` for each scenario and see it pass
