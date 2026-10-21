## 1. Make Local Enter focus the shown diff
Scenarios: `git: Changes panel Enter opens the file`, `git: Changes panel file is an independent normal buffer`
- [x] 1.1 Update the scenarios in `tests/integration/git/test_changes_diff.lua`, driving the real `<CR>` mapping with a populated Local diff, and run `make test FILE=tests/integration/git/test_changes_diff.lua CASE="Changes panel Enter"` to see them fail
- [x] 1.2 Add a small named Changes-view operation that keeps the selected diff open, makes its working-tree buffer independent, places its cursors at the first change, and focuses its right window; use it from `changes.open`
- [x] 1.3 Run `make test FILE=tests/integration/git/test_changes_diff.lua CASE="Changes panel Enter"` and see it pass

## 2. Keep folding structural rows while entering foldable files
Scenarios: `git: Changes panel Enter folds a directory`, `git: Changes panel Enter on a nest parent enters the diff`
- [x] 2.1 Write `git: Changes panel Enter on a nest parent enters the diff` beside the existing directory scenario in `tests/integration/git/test_changes.lua`, driving real `<CR>` on populated `billing` rows, and run `make test FILE=tests/integration/git/test_changes.lua CASE="Changes panel Enter"` to see the new scenario fail while the directory scenario passes
- [x] 2.2 Make `open_selected` dispatch every file row to the diff-entry operation before dispatching structural root and directory rows to folding
- [x] 2.3 Run `make test FILE=tests/integration/git/test_changes.lua CASE="Changes panel Enter"` and see both scenarios pass

## 3. Apply Enter consistently to Branch and commit diffs
Scenarios: `git: Branch tab Enter opens the working file`, `git: Branch commit Enter enters the diff`
- [x] 3.1 Update the Branch file scenario and add the commit-file scenario in `tests/integration/git/test_changes_tabs.lua`, driving real `<CR>` on populated Branch data, and run `make test FILE=tests/integration/git/test_changes_tabs.lua CASE="Branch.*Enter"` to see them fail
- [x] 3.2 Route Branch and commit file rows through the same diff-entry operation without changing their editable or read-only buffers
- [x] 3.3 Run `make test FILE=tests/integration/git/test_changes_tabs.lua CASE="Branch.*Enter"` and see both scenarios pass

## 4. Preserve Enter while a diff is loading
Scenarios: `git: Changes panel Enter while the diff loads enters it once shown`
- [x] 4.1 Add a deterministic Local-tab regression that holds the diff callback, presses the real `<CR>` mapping, and waits for the show event
- [x] 4.2 Carry the Enter intent through the matching in-flight request and clear it whenever that request is dropped
- [x] 4.3 Run the owned case five times, its file once, and its directory once

## Agent decisions

- Treat only a right buffer with empty `buftype` as an independent working-tree buffer, preserving commit-side read-only buffers unchanged.
- Store Enter as a boolean on the matching pending diff request so Local, Branch and commit loads share one race-safe path.
