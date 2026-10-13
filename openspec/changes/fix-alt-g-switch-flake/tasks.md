## 1. Refresh the neo-tree wait budget at each poll
Scenarios: `keymaps: Alt-G switches tree to git status`
- [x] 1.1 Run the existing test `keymaps: Alt-G switches tree to git status` in `tests/integration/keymaps/test_keymaps.lua` under CPU load and reproduce the stale-budget timeout
- [x] 1.2 Compute the unchanged 3000 ms async budget from `H.load_factor()` when each neo-tree poll starts instead of when the test file loads
- [x] 1.3 Run `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="Alt-G switches tree to git status"` and see it pass
