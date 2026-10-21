## Why

Kind: feature

Reported by the user (2026-10-21) about the shipped `changes.copy_commit_url` (add-commit-url-action): "I don't see it
in action list. Also, it should point to a file and line at branch, not commit. In visual selection, line range should
be selected. It should be shown regardless of it having shortcut."

Today the action exists only in the Changes panel (`ft = "gleb-changes"`) and only on a Branch commit row
(`when = branch_commit_selected`), so Find Action in a normal buffer never lists it.

## What Changes

- Replace the commit-row action with an unbound `Copy File URL` action for normal file buffers. It copies the GitHub
  URL of the current file and line at the attached local branch for github.com and GitHub Enterprise hosts such as
  pgw.dev, and remains listed in Find Action whether or not it has an assigned shortcut.
- In visual mode the URL covers the selected line range.
- The URL uses `origin` and the attached local branch, does not require an upstream, and leaves the clipboard unchanged
  with an ERROR notification when `origin` or an attached branch is unavailable.
- Remove `changes.copy_commit_url` from the Changes-panel action catalog. Keep the existing `:Gitlink` permalink
  command unchanged.

## Impact

- Capability: `git`.
- Visible UI: Find Action replaces the context-only `Copy Commit URL` entry with `Copy File URL` in normal and visual
  file-buffer contexts.
- Architecture: add pure URL construction in `lua/gleb/git/file_url.lua`, wire the action in
  `lua/gleb/git/actions.lua`, and remove the old action and runner from `lua/gleb/git/changes/actions.lua` and
  `lua/gleb/git/changes/init.lua`.
- Tests: `tests/integration/git/test_file_url.lua`, `tests/integration/git/test_changes_commit_url.lua`, and
  `tests/integration/git/test_changes_tabs.lua`.
- No plugin dependency is added, removed, or upgraded. No core keymap changes.
- Out of scope: changing `:Gitlink`, adding a default shortcut, publishing a local branch, or selecting a remote other
  than `origin`.
