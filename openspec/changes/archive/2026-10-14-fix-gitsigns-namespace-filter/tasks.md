## 1. Accept every gitsigns namespace in the competing-sign guard
Scenarios: `git: Added line has no competing hunk sign`
- [x] 1.1 Tighten the namespace assertion in `tests/integration/git/test_git.lua`; with a temporary fault (place a sign in the bare `gitsigns` namespace while the guard still accepts only `^gitsigns_`) run `make test FILE=tests/integration/git/test_git.lua CASE="Added line has no competing hunk sign"`, see it fail and record the failure, then remove the fault
- [x] 1.2 Run `make test FILE=tests/integration/git/test_git.lua CASE="Added line has no competing hunk sign"` and see it pass
