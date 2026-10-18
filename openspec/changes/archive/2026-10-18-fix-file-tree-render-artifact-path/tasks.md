## 1. Keep the approved render fixture with its screen test
Scenarios: `file-tree: Project tree render text matches the ANSI artifact`
- [x] 1.1 Run `make test FILE=tests/screen/file-tree/test_project_tree.lua CASE="Project tree render text matches the ANSI artifact"` and see it pass, move the byte-identical approved render to `tests/screen/file-tree/f1_proposed.ansi` and update `approved_tree_lines()` to read it there, run the test again and see it pass
