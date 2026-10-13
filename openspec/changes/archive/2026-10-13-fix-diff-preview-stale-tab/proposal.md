## Why
`diff_preview` sets `state.original_tab` only once (`file_tree/diff_preview.lua:71-73`) and nothing but `reset()` clears it (`:183-192`). After `q` or `<cr>` in the `git_status` tree (`close_all_diffs`, `:174-177`), the next preview started from another tab still returns to the first tab. `close_all_diffs` also leaves the `DiffPreviewFocusGuard` `WinEnter` autocmd and `navigating_until` in place.

Kind: bug

## What Changes
- `close_all_diffs()` / `return_to_original()`: after switching back and closing the diff tab, set `original_tab`, `diff_tab`, `current_file` to nil, `navigating_until` to 0, and clear the focus-guard autocmds.
- `q` in the `git_status` tree keeps returning to the tab the preview started from.

## Capabilities
### Modified Capabilities
- `file-tree`: Diff preview focus and closing (closing resets the whole state); Git status open, close and staging actions (`q` scenario no longer reads `state.original_tab` after close).

## Impact
- Code: `lua/gleb/file_tree/diff_preview.lua`
- Plugins: none added, removed or upgraded
- Core keymaps: unchanged
- Out of scope: the codediff crash (fix-diff-preview-codediff-crash, needed first so the async scenarios can complete); `<space>` staging (fix-neotree-stage-toggle).
