## 1. Raise the shared async wait ceiling
Scenarios: `keymaps: Alt-e closes focused filesystem tree`, `keymaps: Alt-G switches tree to git status`
- [x] 1.1 Use the existing `FAIL in tests/integration/keymaps/test_keymaps.lua | keymaps: Alt-G switches tree to git status:` from run dec37df2 check-1 and `FAIL in tests/integration/keymaps/test_keymaps.lua | keymaps: Alt-e closes focused filesystem tree:` from run 123f41a0 check-3 as the failing evidence; do not reproduce under artificial load
- [x] 1.2 Replace the ineffective re-sampled 3000 ms budget with one 10000 ms `async_ms()` base scaled by `H.load_factor()` and use it for every neo-tree, Differ, and Telescope condition wait without changing assertions
- [x] 1.3 Run `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="Alt-G switches tree to git status"` and `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="Alt-e closes focused filesystem tree"` and see them pass
