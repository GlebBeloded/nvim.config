## Why
neo-tree's `git_status` source shows "working tree clean" in a repository whose only change is a merge conflict, so the conflict (and its U+E727 symbol) never appears. Cause, upstream (pinned neo-tree.nvim `ebd6676`, still on `main` 2026-10-13): `lua/neo-tree/git/parser.lua` porcelain v2 parsing skips leading lines until one starts with a char in `"12?!"` (line 165); unmerged entries start with `u`, so every unmerged entry before the first ordinary (`1`/`2`) entry is dropped. `git status --porcelain=v2` lists entries in path order, so a repo where only `conflict.txt` is unmerged yields `{}` from `require("neo-tree.git").status()`. Found in fix-empty-nerd-font-glyphs: "file-tree: Conflicted file shows conflict symbol" (`tests/integration/file-tree/test_tree_icons.lua`) adds a modified `a.txt` to its fixture to work around it.

Kind: bug

## What Changes
- Report or fix upstream (add `u` to `status_beginning_chars`), then pin the fixed neo-tree via `make update PLUGIN=neo-tree.nvim`.
- Drop the `a.txt` workaround from the conflict fixture so the scenario runs with a lone conflict.

## Capabilities
### Modified Capabilities
None. The file-tree "Conflicted file shows conflict symbol" scenario already describes the intended behaviour; `skip_specs: true`.

## Impact
- Code: `tests/integration/file-tree/test_tree_icons.lua`; `lazy-lock.json` (neo-tree pin)
- Plugins: neo-tree.nvim upgraded once fixed upstream
- Core keymaps: unchanged
- Out of scope: neo-tree icons (fix-empty-nerd-font-glyphs).
