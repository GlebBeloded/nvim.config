## Why

Kind: bug

Reported by the user (2026-10-19): "When I open neovim (from home screen), then open diff tree, home screen is not gone."

Steps: start Neovim with no file, so the dashboard (home screen) shows; open the git Changes panel with its diff view
(Cmd+G / `changes.review`) in a repo with changes. Result (`screenshot.png` in this folder): the Changes panel is on the
left and the diff view opens, but the dashboard window stays open on the right next to the diff, squeezing it.
Expected: the dashboard goes away when the Changes panel or its diff opens, as it does when a file is opened.

## What Changes

- Opening the Changes panel / its diff view from the dashboard replaces the dashboard instead of leaving it beside the
  diff.

## Evidence

- `~/.local/share/nvim/lazy/alpha-nvim/lua/alpha.lua:499-504` marks the dashboard buffer `bufhidden=wipe`,
  `buftype=nofile`, and `filetype=alpha`.
- `lua/gleb/file_tree/view.lua:73-86` accepts only empty-`buftype` editor windows, so the dashboard cannot be selected as
  the Changes panel's editor window.
- `lua/gleb/file_tree/view.lua:108-119` creates another editor window when no eligible window exists, which leaves the
  rejected dashboard window open.
- `lua/gleb/git/changes/view.lua:243-249` uses that selector immediately before showing the panel-owned diff, causing the
  extra editor window observed in `screenshot.png`.

## Impact

- Changes panel editor selection in `lua/gleb/git/changes/view.lua` and `lua/gleb/file_tree/view.lua`; no module layout,
  load-order, or plugin-wiring change.
- No plugin dependency is added, removed, or upgraded.
- Core keymaps do not change; Cmd+G continues to invoke `changes.review`.
- `keymaps: Requirement: Changes review entry point` still holds because `<A-g>` continues to invoke `changes.review`;
  this change only replaces the dashboard when that action opens its panel-owned diff.
- Out of scope: changing the approved Changes panel/diff layout or the dashboard's appearance and behavior for other
  actions.
