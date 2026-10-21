## Why

Kind: bug
Adopt: loop/fix-changes-enter-jumps-to-hunk

Reported by the user (2026-10-21): "also when I press enter in local diff, I don't go to that hunk (it just folds/unfolds)."

In the changes panel's Local tab, pressing Enter only folds or unfolds the row. It does not take the cursor to the change in the diff view.

## What Changes

- Enter on a file in the changes panel's Local tab moves the cursor into the diff view, onto the first hunk of that file.
- The spec step works out the details: what Enter does on folder and root rows (fold), whether the same applies to the Branch tab, and how this relates to `changes.open` and to `fix-changes-diff-interaction`.
- Root and directory rows continue to fold. A file row enters its diff even when that file is also a nesting parent with children.
- Branch and commit-view file rows use the same Enter behavior: focus the displayed diff's right pane at its first change.
- `changes.open` remains the Enter action and Comments-tab thread rows retain their existing specialized behavior.

## Evidence

- `lua/gleb/git/changes/actions.lua:92` maps Enter's `changes.open` action to `open_selected`.
- `lua/gleb/git/changes/init.lua:345` opens a Local file only when it has no `fold_id`; `lua/gleb/git/changes/init.lua:347` therefore sends a foldable file row to `toggle_fold`.
- `lua/gleb/git/changes/view.lua:796` implements file opening by closing the panel-owned diff and editing the working file, so even a non-foldable file does not enter the diff.
- `lua/gleb/diff/view/init.lua:467` already places both diff cursors on the first change, so Enter only needs to focus the shown right pane without rebuilding the view.

## Impact

- `lua/gleb/git/changes/init.lua` and `lua/gleb/git/changes/view.lua` (Enter dispatch and diff focus).
- `tests/integration/git/test_changes.lua`, `tests/integration/git/test_changes_diff.lua`, and `tests/integration/git/test_changes_tabs.lua` (real `<CR>` coverage).
- `pr: Requirement: Comments tab Enter` still holds because thread rows keep the specialized `comments_tab.open` branch ahead of file and structural rows.
- `file-tree: Expanding a compact row shows the last folder's entries` still holds because project-tree Enter dispatch is separate from changes-panel `changes.open`.
- `file-tree: Project tree Enter toggles a folder` still holds because this change does not alter project-tree mappings or folder dispatch.
- `file-tree: Project tree Enter opens a file in the editor window` still holds because this change only changes file-row handling inside the changes panel.
- `file-tree: Project tree opening skips non-editor windows` still holds because project-tree editor-window selection is unchanged.
- `file-tree: Project tree manual expansion stops at the row limit` still holds because project-tree expansion and its 5000-row bound are unchanged.
- `file-tree: Project tree pasting a copy over an existing name asks for a new name` still holds because picker submission and project-tree paste handling are unchanged.
- `file-tree: Enter on a nest parent opens the file` still holds because project-tree nest handling is unchanged.
- `file-tree: Project tree expansion meets the large-tree bound` still holds because this change does not alter project-tree expansion or drawing.
- `file-tree: Project tree unfold all preserves skipped expansion state` still holds because project-tree unfold-all behavior is unchanged.
- `picker: Input prompt ignores a blank query` still holds because picker input submission is unchanged.
- `pr: Enter on a thread opens its line` still holds because Comments-tab thread rows retain their specialized open path.
- `pr: Enter on an unmapped thread shows its diff hunk` still holds because Comments-tab unmapped-thread handling remains ahead of file-row dispatch.
- `pr: An unmapped thread window shows its diff hunk` still holds because thread-window rendering is unchanged.
- `pr: Enter on an empty reply starts writing` still holds because reply-area Enter uses the thread-window action, not `changes.open`.
- `pr: Enter asks before sending a reply` still holds because reply confirmation is unchanged and separate from changes-panel dispatch.
- `shortcuts: Ctrl+Return reaches Neovim as <C-CR> from a real key press` still holds because terminal shortcut delivery and core keymaps are unchanged.
- No plugin dependency is added, removed, or upgraded. No core keymap changes; `<CR>` remains `changes.open`.
- Out of scope: changing diff rendering, cursor placement on selection, fold keys other than Enter, or Comments-tab thread behavior.

## Rejected run
Run on `loop/fix-changes-enter-jumps-to-hunk` was rejected by the judge:
- fix loop exhausted with gates still red: review
- review findings:
  [must-fix] If a panel refresh lands while a diff is loading, a pending Enter is dropped. `lua/gleb/git/changes/view.lua:509-516`: when the result arrives for the still-selected row after `view.generation` changed, the code calls `clear_pending_diff(view)` and then `reload_outdated_diff(view, focus_right)` (`view.lua:411-413`). That call passes no `enter_diff`, so the reloaded diff never runs `enter_shown_diff`. Its right buffer stays panel-owned and unlisted, and it gets unloaded on panel close. This breaks the Open and close SHALL "Its working-tree buffer SHALL become independent and survive panel close" and the scenario "Changes panel Enter while the diff loads enters it once shown". It applies to Local, Branch and commit alike. Refreshes come from FocusGained, BufWritePost and the git-dir watcher (`view.lua:384-396,670-684`).
  
  Reproduced with `make probe` on a 2-file repo with `git.load_diff` held:
  1. Cursor onto b.txt (load held), then `open_selected()`, giving `diff_pending_enter=true`.
  2. Fire `FocusGained`, which bumps the generation.
  3. Release the held load.
  4. Result: `diff_path="local:b.txt"`, `listed=false`, `owned=true` (still in `loaded_buffers`).
  
  Earlier passes missed it because they only exercised the selection-generation stale path, not the refresh-generation one.
  
  Fix: carry the pending Enter into the reload, e.g. capture `view.diff_pending_enter or enter_diff` before clearing and pass it to `request_diff` through `reload_outdated_diff`. Add a test that holds the load, presses `<CR>`, triggers a refresh, waits for the generation bump, then releases and waits on the show event, asserting the right buffer is listed and survives `q`.
  
  [minor] `M.open_file` (`lua/gleb/git/changes/view.lua:827-844`) has no callers left: `open_selected` routes every file row to `enter_diff` (`lua/gleb/git/changes/init.lua:345-346`). It is dead code, flagged in passes 1 and 2 and still present.
  
  [minor] `lua/gleb/diff/view/init.lua:480-488` adds `M.focus_first_change`, but proposal.md `## Impact` does not list `lua/gleb/diff/view/init.lua`. It is only cited under Evidence (`:467`) and implied by tasks 1.2 ("places its cursors at the first change"). Add it to Impact.
- note: flaky test cases (failed, then passed on rerun): tests/integration/git/test_changes_diff.lua | git: Changes panel shows an untracked file as added, tests/integration/plugins/test_startup.lua | plugins: Warm real-config startup stays within budget | uses the 120 ms base budget: tests/integration/plugins/test_startup.lua:49: startup 583.5 ms exceeds load-normalized budget 364 ms
