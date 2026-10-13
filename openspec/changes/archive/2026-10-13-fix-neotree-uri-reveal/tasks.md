# Tasks

## 1. Suppress URI reveal
Scenarios: `keymaps: Alt-e on URI buffer focuses filesystem`
- [x] 1.1 Remove the `H.xfail` wrapper from the existing test `keymaps: Alt-e on URI buffer focuses filesystem` in `tests/integration/keymaps/test_keymaps.lua`, run it, and see it fail because the neo-tree confirmation popup takes focus
- [x] 1.2 In the URI-or-empty-buffer branch of `smart_toggle_neotree`, invoke neo-tree's command API with the `filesystem` source, `focus` action, and `reveal = false`; retain the existing ordinary-file reveal path
- [x] 1.3 Run `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="Alt-e on URI buffer focuses filesystem"` and see it pass
