## 1. Include the declaration under the cursor in references
Scenarios: `lsp: References of a Go function list call sites across packages`
- [x] 1.1 Remove the `H.xfail` wrapper from the existing test `lsp: References of a Go function list call sites across packages` in `tests/e2e/lsp/test_go_references.lua`, run it with `make e2e CASE="lsp: References of a Go function list call sites across packages"`, and see it fail with 4 entries instead of the manifest's 5
- [x] 1.2 Add a small named function in `lua/gleb/keymaps.lua` that calls `telescope.builtin.lsp_references({ include_current_line = true })`, then map `gr` to it
- [x] 1.3 Run `make e2e CASE="lsp: References of a Go function list call sites across packages"` and see it pass

## 2. Bind gr to references with the current line included
Scenarios: `keymaps: gr bound to Telescope references`
- [x] 2.1 Update the existing test `keymaps: gr bound to Telescope references` in `tests/integration/keymaps/test_keymaps.lua` to invoke the callback and see it fail because `include_current_line` is not true
- [x] 2.2 Wrap Telescope references in a small named callback that passes `include_current_line = true`
- [x] 2.3 Run `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="keymaps: gr bound to Telescope references"` and see it pass

## 3. Preserve the updated global gr callback in the git status tree
Scenarios: `file-tree: gr keeps its global meaning in git status tree`
- [x] 3.1 Restore the Telescope stub assertion in the existing test `file-tree: gr keeps its global meaning in git status tree` in `tests/integration/file-tree/test_tree.lua`
- [x] 3.2 Keep the tree free of a buffer-local `gr` mapping so the updated global callback reaches Telescope with `include_current_line = true`
- [x] 3.3 Run `make test FILE=tests/integration/file-tree/test_tree.lua CASE="file-tree: gr keeps its global meaning in git status tree"` and see it pass
