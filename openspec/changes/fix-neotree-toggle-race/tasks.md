## 1. Keep a toggle authoritative over pending filesystem work
Scenarios: `keymaps: Toggle wins over pending filesystem render`
- [x] 1.1 Use the gate evidence `FAIL in tests/integration/keymaps/test_keymaps.lua | keymaps: Alt-G switches tree to git status:` and `FAIL in tests/integration/keymaps/test_keymaps.lua | keymaps: Alt-e closes focused filesystem tree:` as the timing-flake failure; write `keymaps: Toggle wins over pending filesystem render` in `tests/integration/keymaps/test_keymaps.lua` with delayed filesystem completion and see the deterministic regression fail
- [x] 1.2 Make the smallest change in `lua/gleb/keymaps.lua` so the requested close or source switch remains authoritative after an already-pending filesystem render completes
- [x] 1.3 Run `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="Toggle wins over pending filesystem render"` and see it pass
