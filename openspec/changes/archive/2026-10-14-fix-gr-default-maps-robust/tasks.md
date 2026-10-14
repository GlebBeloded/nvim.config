## 1. Make default `gr*` map cleanup robust
Scenarios: `file-tree: gr keeps its global meaning in git status tree`
- [x] 1.1 Add an assertion in `tests/integration/file-tree/test_tree.lua` that a fake global `grz` mapping is removed without an error; with a temporary fault (the current fixed-list cleanup that leaves `grz` mapped), run `make test FILE=tests/integration/file-tree/test_tree.lua CASE="file-tree: gr keeps its global meaning in git status tree"`, see it fail and record the failure, then remove the fault
- [x] 1.2 Run `make test FILE=tests/integration/file-tree/test_tree.lua CASE="file-tree: gr keeps its global meaning in git status tree"` and see it pass
