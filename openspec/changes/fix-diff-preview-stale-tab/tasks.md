## 1. Closing a preview resets the whole state

Scenarios: "file-tree: Return clears tab state and focus guard", "file-tree: Next preview records the new original tab" (regression guard: "file-tree: Reset clears populated state", "file-tree: Return to original tab", "file-tree: Return clears current file")

Layer: integration (`tests/integration/file-tree/test_diff_preview.lua`), since both scenarios need `open_diff` to finish through codediff. If `fix-diff-preview-codediff-crash` has not merged into `auto` (`git log auto --oneline | grep codediff-crash`), wrap both cases in `H.xfail(CODEDIFF_CRASH, ...)` and check the red/green steps with the wrapper commented out locally; never weaken the assertions.

- [x] 1.1 Failing test `T["file-tree: Return clears tab state and focus guard"]`: `open_diff(TRACKED)`, `wait_diff_tab()`, call `DiffPreview.return_to_original()`, then assert `state.original_tab == nil`, `state.diff_tab == nil`, `state.navigating_until == 0` and `#vim.api.nvim_get_autocmds({ group = "DiffPreviewFocusGuard" }) == 0`. Add a small typed helper `focus_guard_count()` next to `tab_count()`
- [x] 1.2 Failing test `T["file-tree: Next preview records the new original tab"]`: open a preview of `TRACKED` from T1, wait, `return_to_original()`, `:tabnew` and record T2, open a preview of a second tracked file (add `TRACKED_B`, e.g. `lua/gleb/file_tree/init.lua`), wait for `state.diff_tab ~= nil`, assert `state.original_tab == T2`, then `return_to_original()` and assert the current tab is T2
- [x] 1.3 Run `make test FILE=tests/integration/file-tree/test_diff_preview.lua` and confirm both fail on the state assertions (stale `original_tab` = T1, guard autocmd still present), not on setup
- [x] 1.4 In `lua/gleb/file_tree/diff_preview.lua` add a LuaCATS `---@class DiffPreviewState` for `M.state` and a named local `clear_state()`: stop and nil `debounce_timer`, `nvim_clear_autocmds({ group = augroup })`, then assign `original_tab`, `diff_tab`, `current_file` = nil and `navigating_until` = 0 on the existing `M.state` table (in place, design Decision)
- [x] 1.5 `close_all_diffs()` = `M.close_current_diff()` then `clear_state()`; `reset()` delegates to `close_all_diffs()`; `M.return_to_original` stays the alias
- [x] 1.6 Tests from 1.1 and 1.2 pass; the unit cases in `tests/unit/file-tree/test_diff_preview_state.lua` ("State starts empty", "Reset clears populated state", "Return to original tab", "Return clears current file") stay green; `make quick`

## 2. q in the git_status tree

Scenarios: "file-tree: q closes preview and tree"

Layer: integration (`tests/integration/file-tree/test_tree.lua`, tree mappings). Same `CODEDIFF_CRASH` xfail rule as task 1.

- [ ] 2.1 Failing test `T["file-tree: q closes preview and tree"]`: in a temp git repo (`git init`, commit a file, modify it; `cd` into it), record tab T, `:Neotree git_status`, wait for the file node, move onto it with `j` (the tree's own preview mapping calls `open_diff`), wait for `state.diff_tab ~= nil` and the tree focused in the diff tab, press `q` in normal mode, then assert current tab is T, the diff tab is no longer valid, `state.current_file` and `state.original_tab` are nil, and no window in the current tab has filetype `neo-tree`
- [ ] 2.2 Show it red by running it with task 1's `diff_preview.lua` change reverted locally (fails on `state.original_tab` still set), then green with it; `git_close` in `lua/gleb/file_tree/init.lua` needs no change, as it does not read `state.original_tab` after closing
- [ ] 2.3 `make quick`, then `make check` green; `make trace` lists the three scenarios as tested
