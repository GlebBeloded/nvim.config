## 1. Guard against anonymous competing signs
Scenarios: `git: Added line has no competing hunk sign`
- [x] 1.1 In `tests/integration/git/test_git.lua`, tighten `git: Added line has no competing hunk sign`, temporarily place a sign on line 2 from `nvim_create_namespace("")`, run `make test FILE=tests/integration/git/test_git.lua CASE="git: Added line has no competing hunk sign"`, and see the ownership assertion fail; then remove the temporary sign
- [x] 1.2 Query line 2 sign extmarks across all namespaces with namespace `-1`, collect the gitsigns namespace ids, and assert every sign extmark belongs to one of them
- [x] 1.3 Run `make test FILE=tests/integration/git/test_git.lua CASE="git: Added line has no competing hunk sign"` and see it pass
