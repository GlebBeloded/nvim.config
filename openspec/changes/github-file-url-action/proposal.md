## Why

Kind: feature

Reported by the user (2026-10-21) about the shipped `changes.copy_commit_url` (add-commit-url-action): "I don't see it
in action list. Also, it should point to a file and line at branch, not commit. In visual selection, line range should
be selected. It should be shown regardless of it having shortcut."

Today the action exists only in the Changes panel (`ft = "gleb-changes"`) and only on a Branch commit row
(`when = branch_commit_selected`), so Find Action in a normal buffer never lists it.

## What Changes

- An action that copies the GitHub URL of the current file and line at the current branch (github.com and GitHub
  Enterprise hosts such as pgw.dev), listed in Find Action in normal file buffers whether or not it has a shortcut.
- In visual mode the URL covers the selected line range.
- The spec step works out the details (URL form, what happens without an upstream or remote, the existing commit-row
  action).

## Impact

- `lua/gleb/git/` (the URL builder from add-commit-url-action), its actions, Find Action listing.
