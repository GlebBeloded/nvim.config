## 1. Make one-fold actions harmless without a fold
Scenarios: `folding: Fold keys without a fold do nothing`
- [x] 1.1 Write the test `folding: Fold keys without a fold do nothing` in `tests/integration/folding/test_shortcuts.lua` through the real `<M-=>` and `<M-->` mappings, assert unchanged lines and cursor with no error message, run `make test FILE=tests/integration/folding/test_shortcuts.lua CASE="Fold keys without a fold do nothing"`, and see it fail
- [x] 1.2 Guard the counted one-fold actions in `lua/gleb/folding/actions.lua` when no applicable fold exists while preserving count behaviour for existing folds
- [x] 1.3 Run `make test FILE=tests/integration/folding/test_shortcuts.lua CASE="Fold keys without a fold do nothing"` and see it pass

## 2. Make terminal paste safe in read-only buffers
Scenarios: `keymaps: Terminal paste ignores a read-only project tree`, `keymaps: Terminal paste edits a normal buffer`
- [x] 2.1 Write the tests `keymaps: Terminal paste ignores a read-only project tree` and `keymaps: Terminal paste edits a normal buffer` in `tests/integration/keymaps/test_paste.lua` through `vim.paste`, using the real populated project tree and a normal buffer, run `make test FILE=tests/integration/keymaps/test_paste.lua`, and see the read-only case fail while the normal-buffer case passes
- [x] 2.2 Guard terminal paste in `lua/gleb/keymaps/init.lua` when the current buffer is unmodifiable while delegating modifiable buffers to Neovim's original paste implementation
- [x] 2.3 Run `make test FILE=tests/integration/keymaps/test_paste.lua` and see both scenarios pass

## Agent decisions

- Swallow harmless one-fold command errors so counts still reach native `zo` and `zc` unchanged.
- Return `false` for paste into an unmodifiable buffer, matching `vim.paste`'s stop-paste contract without modifying content.
