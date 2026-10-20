## Why

Kind: feature

Requested by the user (2026-10-20): "add action to do github (pgw.dev on our enterprise) url to commit, should work
for all githubs".

## What Changes

- An action that gives the GitHub URL of a commit, for github.com and GitHub Enterprise hosts such as pgw.dev; the
  spec step works out the details.
- Add an unbound `Copy Commit URL` action to Find Action while a commit row is selected in the Branch commit view.
- Copy the selected commit's full GitHub-style URL to the system clipboard and report an unavailable `origin`
  without changing the clipboard.

## Impact

- `lua/gleb/git/changes/actions.lua` and `lua/gleb/git/changes/init.lua`: expose and run the context-sensitive
  commit action against the populated Changes panel row.
- `lua/gleb/git/base/rules.lua`: derive a GitHub-style web repository base from HTTPS and SSH remote URLs without
  an enterprise-host allowlist.
- The Find Action picker gains one row only when its opening context is a commit row. Module layout, load order and
  plugin wiring do not change.
- No plugin dependency is added, removed or upgraded. Core keymaps do not change; the new action has no default key.
- Out of scope: opening a browser, changing `:Gitlink`, and promising GitHub-style paths for non-GitHub forges.
