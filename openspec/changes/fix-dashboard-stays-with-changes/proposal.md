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

## Impact

- The Changes panel / diff view open path (`lua/gleb/git/changes/`, `lua/gleb/diff/view/`) and the dashboard's close
  rule; probe which one keeps the dashboard window.
