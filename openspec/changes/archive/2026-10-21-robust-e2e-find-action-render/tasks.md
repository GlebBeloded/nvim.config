## 1. Make the physical Find Action render registry-aware
Scenarios: `find-action: Physical Find Action workflow persists an assignment`
- [x] 1.1 Update `tests/e2e/find-action/test_e2e.lua` to obtain expected action rows and totals from the populated child registry while driving the real `cmd+shift+a`, query, `<CR>`, assignment, assigned shortcut, and restart path; run `make e2e CASE="Physical Find Action workflow persists an assignment"` and see it fail because the approved-screen helper still accepts only the static registry-dependent fixtures
- [x] 1.2 Change `tests/e2e/find-action/screens.lua` and its caller to build registry-dependent expected rows and totals from those live child values while retaining the fixed palette frame, assignment chrome, physical-key transitions, and persistence assertions
- [x] 1.3 Run `make e2e CASE="Physical Find Action workflow persists an assignment"` and see it pass

## Agent decisions

- Pass structured matched rows and the actionable count from the child so registry content is live while fixed screen chrome remains independently specified.
