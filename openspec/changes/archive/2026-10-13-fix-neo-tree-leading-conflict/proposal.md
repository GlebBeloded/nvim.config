## Why
neo-tree's `git_status` source shows "working tree clean" in a repository whose only change is a merge conflict, so the conflict (and its U+E727 symbol) never appears. Cause, upstream (pinned neo-tree.nvim `ebd6676`, still on `main` 2026-10-13): `lua/neo-tree/git/parser.lua` porcelain v2 parsing skips leading lines until one starts with a char in `"12?!"` (line 165); unmerged entries start with `u`, so every unmerged entry before the first ordinary (`1`/`2`) entry is dropped. `git status --porcelain=v2` lists entries in path order, so a repo where only `conflict.txt` is unmerged yields `{}` from `require("neo-tree.git").status()`. Found in fix-empty-nerd-font-glyphs: "file-tree: Conflicted file shows conflict symbol" (`tests/integration/file-tree/test_tree_icons.lua`) adds a modified `a.txt` to its fixture to work around it.

Kind: bug

## What Changes
- Upstream has no fix, issue or PR (checked 2026-10-13: v3.x tip and main still use `"12?!"`; cause is b48ed11632, PR #2008). Opening an upstream PR is left to the user.
- Work around it locally: after neo-tree setup, use porcelain v1 status (`require("neo-tree.git")._supported_status_porcelain_version = 1`, `git/init.lua:115`; v1's `status_chars` includes `U`), in the neo-tree plugin config with a comment naming the upstream bug so it is dropped once fixed upstream.
- Drop the `a.txt` workaround from the conflict fixture so the scenario runs with a lone conflict.

## Capabilities
### Modified Capabilities
None. The file-tree "Conflicted file shows conflict symbol" scenario already describes the intended behaviour; `skip_specs: true`.

## Impact
- Code: neo-tree plugin config; `tests/integration/file-tree/test_tree_icons.lua`
- Plugins: none added, removed or upgraded
- Core keymaps: unchanged
- Out of scope: neo-tree icons (fix-empty-nerd-font-glyphs).
