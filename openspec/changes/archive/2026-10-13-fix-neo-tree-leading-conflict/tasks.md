## 1. Show a leading conflict in neo-tree
Scenarios: `file-tree: Conflicted file shows conflict symbol`
- [x] 1.1 Update the existing test `file-tree: Conflicted file shows conflict symbol` in tests/integration/file-tree/test_tree_icons.lua to remove the unrelated `a.txt` modification, then run it and see it fail
- [x] 1.2 After neo-tree setup, force its Git status module to use porcelain v1 and explain the upstream parser bug in a removal comment
- [x] 1.3 Run `make test FILE=tests/integration/file-tree/test_tree_icons.lua CASE="Conflicted file shows conflict symbol"` and see it pass
