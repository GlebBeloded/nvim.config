## 1. Consolidate the gitsigns regression case
Scenarios: `git: Added line shows bar sign`
- [x] 1.1 Run `make test FILE=tests/integration/git/test_git.lua CASE="Added line shows bar sign"` and see it pass
- [x] 1.2 Remove the duplicate case from `tests/integration/git/test_gitsigns.lua` and make the retained case assert that no `MiniDiff*` namespace contributes hunk signs
- [x] 1.3 Run `make test FILE=tests/integration/git/test_git.lua CASE="Added line shows bar sign"` and see it pass
- [x] 1.4 Run `make trace` and see 0 duplicate cases
