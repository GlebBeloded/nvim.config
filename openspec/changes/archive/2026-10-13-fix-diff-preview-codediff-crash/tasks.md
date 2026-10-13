# Tasks

## Conventions for this change

- Layer: integration (`docs/testing.md`, "Adding a test for a scenario"). `open_diff` needs the real config (neo-tree, vscode-diff.nvim, git). The tests already exist in `tests/integration/file-tree/test_diff_preview.lua`. They are only wrapped in `H.xfail`, so no new test file is needed.
- Plugins: none added. The fix uses the pinned vscode-diff.nvim's own constructor `require("codediff.core.path").make_ref(any_path, root) -> Path` (`codediff/core/path.lua:102`). This is the same call the plugin's `:CodeDiff` command makes (design.md, Decisions).
- Types: `SessionConfig.original` / `.modified` are `Path` (`codediff/ui/view/init.lua:25-29`). Do not hand-build `{ relative, absolute }` tables, and do not add `---@diagnostic disable`.
- Out of scope: `original_tab`, the debounce and the focus guard (fix-diff-preview-stale-tab).

## 1. Pass Path refs to codediff

Scenarios: "file-tree: Diff tab is created", "file-tree: Neo-tree is opened and focused in diff tab".

- [x] 1.1 Failing tests `file-tree: Diff tab is created` and `file-tree: Neo-tree is opened and focused in diff tab` in `tests/integration/file-tree/test_diff_preview.lua`:
  - unwrap both cases from `H.xfail(CODEDIFF_CRASH, …)` so they are plain `function() … end`, and delete the now-unused `CODEDIFF_CRASH` local. Leave the case bodies unchanged.
  - `make test FILE=tests/integration/file-tree/test_diff_preview.lua` fails both cases. `wait_diff_tab()` is `false`, and the child logs `codediff/ui/view/helpers.lua:34: attempt to index local 'ref' (a nil value)`.
- [x] 1.2 In `lua/gleb/file_tree/diff_preview.lua`, add `local codediff_path = require("codediff.core.path")` next to the lazy `git` / `view` requires inside `open_diff` (lines 30-31). Requiring it at the top of the file would load the plugin before lazy.nvim does.
- [x] 1.3 In the `session_config` literal (currently `diff_preview.lua:61-68`), replace `original_path = relative_path` / `modified_path = relative_path` with `original = codediff_path.make_ref(relative_path, git_root)` / `modified = codediff_path.make_ref(relative_path, git_root)`. Keep `mode`, `git_root`, `original_revision` and `modified_revision` as they are.
- [x] 1.4 `make test FILE=tests/integration/file-tree/test_diff_preview.lua`: both scenario cases pass, and the other cases in the file still pass ("Current file is tracked immediately", "Original tab is saved", "File outside a repository", "Focus moves to neo-tree", …).
- [x] 1.5 `make types`: no `SessionConfig` field or `param-type-mismatch` hit left in `diff_preview.lua` (formerly lines 60 and 81). If a hit remains, fix the field it names against the plugin's `---@class SessionConfig`. Do not suppress it.
- [x] 1.6 Found while making 1.4 green: once the crash is gone, codediff's async render jumps to the first change (`diff.jump_to_first_change`, `codediff/ui/view/render.lua:148-151`) after `focus_neo_tree()`, so "Neo-tree is opened and focused in diff tab" fails. Pass `M.focus_neo_tree` as the `on_ready` callback of `view.create` (`codediff/ui/view/init.lua:43`) so neo-tree is refocused once the view is ready.

## 2. Integration

- [x] 2.1 `make quick` is green (lint, trace, file-tree mini.test layers, types).
- [x] 2.2 `make check` is green. The previous gate's `e2e` (a concurrent worktree synced over the shared guest checkout: queued as `fix-sandbox-shared-guest-checkout`) and `smoke-startup` (host load ~80) failures pass when rerun alone.
