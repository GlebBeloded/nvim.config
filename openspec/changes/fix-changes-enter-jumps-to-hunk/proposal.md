## Why

Kind: bug

Reported by the user (2026-10-21): "also when I press enter in local diff, I don't go to that hunk (it just folds/unfolds)."

In the changes panel's Local tab, pressing Enter only folds or unfolds the row. It does not take the cursor to the change in the diff view.

## What Changes

- Enter on a file in the changes panel's Local tab moves the cursor into the diff view, onto the first hunk of that file.
- The spec step works out the details: what Enter does on folder and root rows (fold), whether the same applies to the Branch tab, and how this relates to `changes.open` and to `fix-changes-diff-interaction`.

## Impact

- `lua/gleb/git/changes/` (Enter handling), and the diff view's cursor placement from `fix-changes-diff-interaction`.
