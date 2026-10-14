## 1. Guard against every competing hunk sign
Scenarios: `git: Added line has no competing hunk sign`
- [x] 1.1 Run `make test FILE=tests/integration/git/test_git.lua CASE="Added line has no competing hunk sign"` and see it pass, change the test to assert every sign extmark on line 2 belongs to a `gitsigns_*` namespace while retaining the existing bar-sign and mini.diff checks, run it again and see it pass
