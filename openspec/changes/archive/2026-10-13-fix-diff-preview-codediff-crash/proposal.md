## Why
`diff_preview.open_diff(p)` crashes in its scheduled callback inside codediff `view.create` (`codediff/ui/view/helpers.lua:34: attempt to index local 'ref' (a nil value)`), so no diff tab is created and neo-tree is never opened in it. Cause: the pinned vscode-diff.nvim (`dc38f0b`, lazy-lock.json) reads `session_config.original` / `session_config.modified` as Path refs (`codediff/ui/view/init.lua:25-29`, built with `codediff.core.path.make_ref(path, git_root)`), but `file_tree/diff_preview.lua:61-68` still passes the old `original_path` / `modified_path` strings. Tests "Diff tab is created" and "Neo-tree is opened and focused in diff tab" are `H.xfail` (`tests/integration/file-tree/test_diff_preview.lua:56,65`).

Kind: bug

## What Changes
- Build the session config with `original` / `modified` refs from `require("codediff.core.path").make_ref(relative_path, git_root)` instead of `original_path` / `modified_path`.
- Remove `H.xfail` (and `CODEDIFF_CRASH`) from the two tests; they must pass.
- Fix the `---@type SessionConfig` / `param-type-mismatch` hits at `diff_preview.lua:60,81` if this change touches them.

## Capabilities
### Modified Capabilities
None. The spec already describes the intended behaviour (file-tree: "Diff tab is created", "Neo-tree is opened and focused in diff tab"); `skip_specs: true`.

## Impact
- Code: `lua/gleb/file_tree/diff_preview.lua`, `tests/integration/file-tree/test_diff_preview.lua`
- Plugins: none added, removed or upgraded (works with the pinned vscode-diff.nvim)
- Core keymaps: unchanged
- Out of scope: stale `original_tab` and focus-guard reset (fix-diff-preview-stale-tab); upgrading or replacing vscode-diff.nvim.
