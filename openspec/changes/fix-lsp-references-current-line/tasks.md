## 1. Include the declaration under the cursor in references
Scenarios: `lsp: References of a Go function list call sites across packages`
- [x] 1.1 Remove the `H.xfail` wrapper from the existing test `lsp: References of a Go function list call sites across packages` in `tests/e2e/lsp/test_go_references.lua`, run it with `make e2e CASE="lsp: References of a Go function list call sites across packages"`, and see it fail with 4 entries instead of the manifest's 5
- [x] 1.2 Add a small named function in `lua/gleb/keymaps.lua` that calls `telescope.builtin.lsp_references({ include_current_line = true })`, then map `gr` to it
- [x] 1.3 Run `make e2e CASE="lsp: References of a Go function list call sites across packages"` and see it pass
