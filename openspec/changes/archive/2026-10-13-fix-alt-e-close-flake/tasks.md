## 1. Scale the neo-tree close wait under load
Scenarios: `keymaps: Alt-e closes focused filesystem tree`
- [x] 1.1 Run the existing test `keymaps: Alt-e closes focused filesystem tree` in `tests/integration/keymaps/test_keymaps.lua` and see it pass
- [x] 1.2 Scale the keymaps async plugin wait budget from its unchanged 3000 ms idle baseline with `H.load_factor()`, retaining the observable no-tree-window assertion
- [x] 1.3 Run `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="Alt-e closes focused filesystem tree"` and see it pass
