## 1. Make the mini.diff guard deterministic
Scenarios: `git: Added line has no competing hunk sign`
- [x] 1.1 Update the existing test `git: Added line has no competing hunk sign` in tests/integration/git/test_git.lua to assert `mini.diff` is neither loaded nor registered with lazy.nvim, and use a temporary mini.diff registration to see it fail
- [x] 1.2 Remove the temporary registration while retaining the deterministic package and lazy.nvim plugin-table assertions alongside the existing sign check
- [x] 1.3 Run `make test FILE=tests/integration/git/test_git.lua CASE="Added line has no competing hunk sign"` and see it pass
