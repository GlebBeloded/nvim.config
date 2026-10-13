# Tasks

## 1. Rename the diff preview focus-guard augroup
Scenarios: `file-tree: Return clears tab state and focus guard`
- [x] 1.1 Update the existing test `file-tree: Return clears tab state and focus guard` in tests/integration/file-tree/test_diff_preview.lua to query `gleb_file_tree_focus_guard`, assert the guard exists before return and is empty afterward, then run it and see it fail
- [x] 1.2 Rename the augroup in lua/gleb/file_tree/diff_preview.lua to `gleb_file_tree_focus_guard`
- [x] 1.3 Run `make test FILE=tests/integration/file-tree/test_diff_preview.lua CASE="Return clears tab state and focus guard"` and see it pass
