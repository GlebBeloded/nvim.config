## 1. Replace every Changes-panel layout with the project tree
Scenarios: `git: Project tree replaces the changes panel`, `git: Project tree replaces a last-window changes panel`
- [x] 1.1 Write the test `git: Project tree replaces a last-window changes panel` in `tests/integration/git/test_changes_diff.lua`, driving the registered `file_tree.toggle` action against the populated `dirty` fixture after its editor window closes, and see it fail while the existing diff-view replacement scenario remains covered
- [x] 1.2 Make Changes-panel replacement preserve a valid window while closing the sole panel, without changing normal panel and owned-diff teardown
- [x] 1.3 Run `make test FILE=tests/integration/git/test_changes_diff.lua CASE="Project tree replaces"` and see both scenarios pass
