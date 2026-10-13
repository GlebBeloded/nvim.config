## 1. Consolidate the gitsigns regression case
Scenarios: `git: Added line shows bar sign`, `git: Added line has no competing hunk sign`
- [x] 1.1 Reproduce the duplicate `git: Added line shows bar sign` case with `make trace`
- [x] 1.2 Preserve and harden the existing bar-sign case, and make a distinct case assert that no `MiniDiff*` namespace contributes hunk signs
- [x] 1.3 Run both touched integration test files and see both scenarios pass
- [x] 1.4 Run `make trace` and see 0 duplicate cases
