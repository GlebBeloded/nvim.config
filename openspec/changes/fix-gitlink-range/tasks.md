# Tasks

## 1. Preserve ranged Gitlink endpoints

Scenarios: `git: Gitlink copies range URL`

- [x] 1.1 Add the headless integration test `git: Gitlink copies range URL`, execute `make test-integration FILE=tests/integration/git/test_gitlink.lua CASE="Gitlink copies range URL"`, and confirm it fails by producing `#L3-L3` instead of `#L3-L5`.
- [x] 1.2 Update the `:Gitlink` adapter to generate a link from the command's inclusive `line1` and `line2`, remove the stale plugin-patching comment, and verify the same targeted scenario passes with `#L3-L5` in register `+`.
