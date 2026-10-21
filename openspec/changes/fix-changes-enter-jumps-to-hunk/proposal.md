## Why

Kind: bug
Adopt: loop/fix-changes-enter-jumps-to-hunk

Reported by the user (2026-10-21): "also when I press enter in local diff, I don't go to that hunk (it just folds/unfolds)."

In the changes panel's Local tab, pressing Enter only folds or unfolds the row. It does not take the cursor to the change in the diff view.

## What Changes

- Enter on a file in the changes panel's Local tab moves the cursor into the diff view, onto the first hunk of that file.
- The spec step works out the details: what Enter does on folder and root rows (fold), whether the same applies to the Branch tab, and how this relates to `changes.open` and to `fix-changes-diff-interaction`.

## Impact

- `lua/gleb/git/changes/` (Enter handling), and the diff view's cursor placement from `fix-changes-diff-interaction`.

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
