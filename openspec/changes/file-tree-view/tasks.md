## 1a. Fixture and row model

Scenarios: `file-tree: Project tree lists folders first in case-insensitive order`, `file-tree: Project tree hides the git folder`

- [x] 1a.1 Add `treeproj` to `tests/fixtures/build.sh` exactly as specified by design.md. Write the scenarios in `tests/unit/file-tree/test_model.lua` against a populated fixture copy through `model.rows` and `fs.lua`; add sort-key and `.git` filtering cases, and see them fail.
- [x] 1a.2 Add typed, pure `lua/gleb/file_tree/model.lua` and the scan/cache layer in `lua/gleb/file_tree/fs.lua`; keep `model.parse_status` public for `git-changes-tree` reuse.
- [x] 1a.3 Run `make test FILE=tests/unit/file-tree/test_model.lua` and see it pass.

## 1b. Compact folder chains

Scenarios: `file-tree: Single-child folders share one row`, `file-tree: Expanding a compact row shows the last folder's entries`

- [x] 1b.1 Write the scenarios in `tests/unit/file-tree/test_model.lua`, driving `model.rows` with populated scans and expansion state, and see them fail.
- [x] 1b.2 Implement compact-chain rows and last-folder expansion in `lua/gleb/file_tree/model.lua` and cached scans in `lua/gleb/file_tree/fs.lua`.
- [x] 1b.3 Run `make test FILE=tests/unit/file-tree/test_model.lua` and see it pass.

## 2a. Neo-tree split and row rendering

Scenarios: `file-tree: Project tree root row names the project`, `file-tree: Project tree rows have icons and no guides`, `file-tree: Project tree highlight colours come from the palette`

- [x] 2a.1 Write these scenarios in `tests/integration/file-tree/test_project_tree.lua`, opening the real `treeproj` picker data and inspecting lines, extmarks and `expect_hl_colors`; see them fail.
- [x] 2a.2 Move neo-tree setup verbatim from `lua/gleb/file_tree/init.lua` to `lua/gleb/file_tree/neo_tree.lua`; make `init.lua` require it and then call `view.setup()`. Add `lua/gleb/file_tree/render.lua` with lines, per-row extmarks and highlight groups redefined on `ColorScheme`.
- [x] 2a.3 Run `make test FILE=tests/integration/file-tree/test_project_tree.lua` for these cases and `make test FILE=tests/integration/file-tree/test_tree.lua`; see them pass.

## 2b. Per-tab window and toggle

Scenarios: `file-tree: Project tree opens on the left at width 35`, `file-tree: Project tree toggle closes a focused tree`, `file-tree: Project tree toggle focuses an open tree`, `file-tree: Project tree toggle reveals the current file`, `file-tree: Project tree closes with the last window`

- [x] 2b.1 Write these scenarios in `tests/integration/file-tree/test_project_tree.lua`, driving `file_tree.toggle` with real file buffers in populated tabs, and see them fail.
- [x] 2b.2 Add `lua/gleb/file_tree/view.lua` with state, buffer names and autocmd teardown keyed by tabpage handle. Append the unbound `file_tree.toggle` and `file_tree.reveal` actions, and implement `QuitPre` without group-wide clearing.
- [x] 2b.3 Run `make test FILE=tests/integration/file-tree/test_project_tree.lua` for these cases and see them pass.

## 2c. Transition wiring and bufferline

Scenarios: `file-tree: Project tree actions start unbound`, `bufferline: tabs start after the open project tree`

- [x] 2c.1 Write the file-tree case in `tests/integration/file-tree/test_project_tree.lua` and the bufferline case in `tests/screen/bufferline/test_bufferline_screen.lua`; see them fail.
- [x] 2c.2 Keep `<A-e>` and `<A-G>` on neo-tree, and add the `gleb-file-tree` offset to `lua/gleb/bufferline.lua` without removing the neo-tree offset.
- [x] 2c.3 Run both test files and see them pass.

## 3a. Eligible editor targets

Scenarios: `file-tree: Project tree opening skips non-editor windows`, `file-tree: A file cannot replace the project tree buffer`, `file-tree: Project tree split windows keep editor options`, `file-tree: Project tree tab windows keep editor options`

- [x] 3a.1 Write these scenarios in `tests/integration/file-tree/test_project_tree.lua`, creating real neo-tree, quickfix, terminal, floating and diff-view windows before driving `<CR>`, `v`, `s`, `t` and `:edit`; see them fail.
- [x] 3a.2 Implement the named eligible-editor selector in `lua/gleb/file_tree/view.lua`, run opens from that window, restore a replaced tree buffer, and keep tree-only options out of new editor windows.
- [x] 3a.3 Run `make test FILE=tests/integration/file-tree/test_project_tree.lua` for these cases and see them pass.

## 3b. Tree-window hygiene

Scenarios: `file-tree: Project tree disables editor-only window features`, `file-tree: Project tree preserves the original cursor setting`

- [x] 3b.1 Write these scenarios in `tests/integration/file-tree/test_project_tree.lua`, using the real ufo attachment and mode changes, and see them fail.
- [x] 3b.2 Set `foldenable`, `foldmethod` and `statuscolumn` locally, detach ufo, and save `guicursor` once while hiding it only in normal and visual modes.
- [x] 3b.3 Run `make test FILE=tests/integration/file-tree/test_project_tree.lua` for these cases and see them pass.

## 3c. Close-if-last with both trees

Scenarios: `file-tree: Project tree closes before last editor with close`, `file-tree: Project and neo-tree close before the last editor`

- [ ] 3c.1 Write these scenarios in `tests/integration/file-tree/test_project_tree.lua`, opening the real project tree and neo-tree before driving `:close` or `:q`; see them fail.
- [ ] 3c.2 Make `QuitPre` count both tree filetypes and close them before the last eligible editor for either close command.
- [ ] 3c.3 Run `make test FILE=tests/integration/file-tree/test_project_tree.lua` for these cases and see them pass.

## 4a. Open and close keys

Scenarios: `file-tree: Project tree Enter toggles a folder`, `file-tree: Project tree Enter opens a file in the editor window`, `file-tree: Project tree h on a file collapses its folder`, `file-tree: Project tree q closes the tree`

- [ ] 4a.1 Write these scenarios in `tests/integration/file-tree/test_project_tree.lua`, pressing the real buffer-local keys on populated rows, and see them fail.
- [ ] 4a.2 Add the scoped open, close-node and close actions to `lua/gleb/file_tree/actions.lua` and their keys to `settings/keymap.json`.
- [ ] 4a.3 Run `make test FILE=tests/integration/file-tree/test_project_tree.lua` for these cases and see them pass.

## 4b. Split and tab keys

Scenarios: `file-tree: Project tree v opens a vertical split`, `file-tree: Project tree s opens a horizontal split`, `file-tree: Project tree t opens a new tab`

- [ ] 4b.1 Write these scenarios in `tests/integration/file-tree/test_project_tree.lua`, pressing `v`, `s` and `t` on the populated `Makefile` row, and see them fail.
- [ ] 4b.2 Add the scoped split, vertical-split and tab actions and their keys.
- [ ] 4b.3 Run `make test FILE=tests/integration/file-tree/test_project_tree.lua` for these cases and see them pass.

## 4c. Fold keys

Scenarios: `file-tree: Project tree za on a file collapses its folder`, `file-tree: Project tree zM collapses every folder`, `file-tree: Project tree zR expands every folder`, `file-tree: Project tree unfold all stops at the row limit`

- [ ] 4c.1 Write these scenarios in `tests/integration/file-tree/test_project_tree.lua`, pressing the real fold keys on populated rows, and see them fail.
- [ ] 4c.2 Add the scoped fold actions and keys; implement breadth-first unfold with the 5000-row cap.
- [ ] 4c.3 Run `make test FILE=tests/integration/file-tree/test_project_tree.lua` for these cases and see them pass.

## 4d. Action ownership and assignment

Scenarios: `file-tree: Project tree keys come from the keymap file`

- [ ] 4d.1 Write the scenario in `tests/integration/file-tree/test_project_tree.lua` against the real buffer mappings and see it fail.
- [ ] 4d.2 Remove `file_tree = "neo-tree"` from `ADAPTER_PLUGINS` in `lua/gleb/find_action/assign.lua`. Move the adapter fixture action in `tests/integration/find-action/test_assign.lua` from `file_tree.open` to a `neo_tree.` id, keeping every assertion.
- [ ] 4d.3 Run `make test FILE=tests/integration/file-tree/test_project_tree.lua` for this case and `make test CAPS=find-action`; see them pass.

## 4e. Manual expansion limit

Scenarios: `file-tree: Project tree manual expansion stops at the row limit`

- [ ] 4e.1 Write the scenario in `tests/integration/file-tree/test_project_tree.lua`, pressing `<CR>` on a populated oversized folder, and see it fail.
- [ ] 4e.2 Apply the shared 5000-row safety check to manual folder expansion and emit the specified WARN.
- [ ] 4e.3 Run `make test FILE=tests/integration/file-tree/test_project_tree.lua` for this case and see it pass.

## 5a1. Follow and reveal

Scenarios: `file-tree: Project tree follows the current file`, `file-tree: Project tree ignores files outside the root`, `file-tree: Project tree reveal focuses the current file`, `file-tree: Project tree reveal tolerates a deleted file`, `file-tree: Project tree follow tolerates a deleted file`

- [ ] 5a1.1 Write these scenarios in `tests/integration/file-tree/test_project_live.lua`, driving `:edit`, `BufEnter` and `file_tree.reveal` against real buffers and populated data, and see them fail.
- [ ] 5a1.2 Implement follow and reveal through the shared path normalizer; deleted files select the root without errors or notifications.
- [ ] 5a1.3 Run `make test FILE=tests/integration/file-tree/test_project_live.lua` for these cases and see them pass.

## 5a2. Toggle and non-file resilience

Scenarios: `file-tree: Project tree toggle tolerates a deleted file`, `file-tree: Project tree does not follow a directory buffer`

- [ ] 5a2.1 Write these scenarios in `tests/integration/file-tree/test_project_live.lua`, driving the real toggle action and directory buffer, and see them fail.
- [ ] 5a2.2 Route toggle through normalization and ignore directory buffers without moving the tree cursor.
- [ ] 5a2.3 Run `make test FILE=tests/integration/file-tree/test_project_live.lua` for these cases and see them pass.

## 5a3. Normalized and hostile paths

Scenarios: `file-tree: Project tree normalizes a symlinked root`, `file-tree: Project tree cuts a symlink loop`, `file-tree: Project tree tolerates an unreadable folder`

- [ ] 5a3.1 Write these scenarios in `tests/integration/file-tree/test_project_live.lua`, using real symlinks and `chmod 000`, and see them fail.
- [ ] 5a3.2 Add the single nearest-existing-parent `normalize(path)` implementation and realpath seen-set; degrade unreadable scans to empty rows.
- [ ] 5a3.3 Run `make test FILE=tests/integration/file-tree/test_project_live.lua` for these cases and see it pass.

## 5b1. Watched filesystem updates and compact chains

Scenarios: `file-tree: A compact chain splits when a folder gains an entry`, `file-tree: Every compact chain member is watched`, `file-tree: Project tree shows files created outside Neovim`, `file-tree: Project tree recolours a written file`, `file-tree: Project tree recolours after staging outside Neovim`

- [ ] 5b1.1 Write these scenarios in `tests/integration/file-tree/test_project_live.lua`; external changes use `vim.system` (`touch`, `mkdir`, `git add`), never a hand-built tree state. See them fail.
- [ ] 5b1.2 Add `lua/gleb/file_tree/watch.lua`; watch every cached scan feeding a row, invalidate only affected caches, debounce redraws and request git refreshes.
- [ ] 5b1.3 Run `make test FILE=tests/integration/file-tree/test_project_live.lua` for these cases and see them pass.

## 5b2. Watch lifecycle and deletion

Scenarios: `file-tree: Project tree watchers stop when the tree closes`, `file-tree: Project tree prunes a deleted expanded folder`, `file-tree: Project tree caps watched folders`

- [ ] 5b2.1 Write these scenarios in `tests/integration/file-tree/test_project_live.lua`, deleting an expanded real folder and lowering the production cap through its test seam; see them fail.
- [ ] 5b2.2 Reference-count handles by normalized root, prune deleted entries and expansion state, clamp the cursor, close obsolete handles, and enforce `MAX_WATCH_HANDLES` without hiding rows.
- [ ] 5b2.3 Run `make test FILE=tests/integration/file-tree/test_project_live.lua` for these cases and see them pass.

## 5b3. Two-tab root and view isolation

Scenarios: `file-tree: Project tree shares root work across tabs`, `file-tree: Project tree isolates tabpage state`

- [ ] 5b3.1 Write the two-tab scenarios in `tests/integration/file-tree/test_project_live.lua`, opening real trees for one root and closing the first tab before reusing the second; see them fail.
- [ ] 5b3.2 Keep git/watch state per root with handle refcounts, and view buffers, cursors and autocmd ids per tabpage handle.
- [ ] 5b3.3 Run `make test FILE=tests/integration/file-tree/test_project_live.lua` for these cases and see them pass.

## 5c. Atomic per-root persistence and re-rooting

Scenarios: `file-tree: Project tree re-roots on a cwd change`, `file-tree: Project tree expanded folders persist per root`, `file-tree: Project tree drops a stored folder that is gone`, `file-tree: Project tree atomically merges expansion state`, `file-tree: Project tree re-roots across git worktrees`

- [ ] 5c.1 Write these scenarios in `tests/integration/file-tree/test_project_live.lua`, using two real roots and linked git worktrees; see them fail.
- [ ] 5c.2 Add `lua/gleb/file_tree/expanded.lua` with per-root merge and temporary-file atomic replacement. Re-root only the current tab and refresh `git rev-parse --show-toplevel --absolute-git-dir`.
- [ ] 5c.3 Run `make test FILE=tests/integration/file-tree/test_project_live.lua` for these cases and see them pass.

## 6a. Git status parsing and colours

Scenarios: `file-tree: Project tree colours changed files`, `file-tree: Project tree folders take the strongest status below them`, `file-tree: Project tree colours renamed and conflicted files`, `file-tree: Project tree reads git status without optional locks`, `file-tree: Project tree outside a repository has no git colours`

- [ ] 6a.1 Write these scenarios in `tests/integration/file-tree/test_project_git.lua`, each on its own populated `treeproj` copy; add unit cases in `tests/unit/file-tree/test_model.lua` for porcelain v2 `-z` records `1`, `2`, `u`, `?`, untracked folders and precomputed folder precedence. See them fail.
- [ ] 6a.2 Add `lua/gleb/file_tree/git.lua` with async normalized-root state and render the precomputed folder status once per result.
- [ ] 6a.3 Run both test files for these cases and see them pass.

## 6b. Git refresh throttling

Scenarios: `file-tree: Project tree runs git status once per burst`

- [ ] 6b.1 Write the scenario in `tests/integration/file-tree/test_project_git.lua` against 20 real writes and `git.state.runs`, and see it fail.
- [ ] 6b.2 Add debounce, single-flight dirty follow-up, generations and `state.last_cmd` to `lua/gleb/file_tree/git.lua`.
- [ ] 6b.3 Run `make test FILE=tests/integration/file-tree/test_project_git.lua` for this case and see it pass.

## 7. Approved render and extmark proof

Scenarios: `file-tree: Project tree matches the approved render`, `file-tree: Project tree rows expose their highlight groups`, `file-tree: Project tree render text matches the ANSI artifact`

- [ ] 7.1 Write the screen cases in `tests/screen/file-tree/test_project_tree.lua`: copy the populated `treeproj` fixture to `~/work/billing`, remove ignored entries, disable LSP and diagnostics, drive the real tree keys, compare tree text with `renders/f1_proposed.ansi` verbatim using real glyphs, assert `H.expect_screenshot`, and assert the Proposed F1 colour mask. Add integration extmark assertions and `expect_hl_colors` for every used `DevIcon*` and `FileTree*` group. See them fail.
- [ ] 7.2 Adjust `lua/gleb/file_tree/render.lua` until the tests pass. Compare `make render` with `renders/f1_proposed.ansi` and review the reference screenshot against that artifact before commit.
- [ ] 7.3 Update only the `file_tree/` row of the module map in `docs/architecture.md` to describe the project tree beside neo-tree until `tree-diff-cutover`.
- [ ] 7.4 Run `make check`.

## Agent decisions

- `fs.tree` passes a root and scan function into `model.rows`, keeping the row model pure while sharing the filesystem cache.
- Task 2a introduces `view.setup()` only as the render-highlight owner required by the entry-point order; task 2b extends it with per-tab windows.
- Eligible editor selection remembers the latest valid `WinEnter` per tab and falls back to another valid editor, so special windows never become targets.
- Cursor hiding queries the current mode and keeps one original `guicursor`; per-view window and mode events restore it whenever the tree is not focused in normal or visual mode.

## Stuck

Task 3c remains unticked. The `Project tree closes before last editor with close` scenario stays red with `tree tab did not close`; the real project-and-neo-tree `:q` scenario passes.

- Probe: neo-tree opens beside the project tree when its real `dir=` is supplied (the sandbox's `/var` alias otherwise opens neo-tree's cwd confirmation popup). After `:close`, the command returns successfully but the target tab remains; a subsequent direct `nvim_win_close` succeeds and removes that tab.
- Attempt 1: close the project and neo-tree windows synchronously in `QuitPre`, then schedule a guarded close of the still-valid editor window. The target tab remained after the scheduled callback.
- Attempt 2: count only eligible editors, add a reentrancy guard, close both tree types, and close the editor window directly. The same behavior assertion failed.
- Saved second attempt: `/Users/hlebbeladzed/.archon/workspaces/GlebBeloded/nvim.config/artifacts/runs/3bb4a2e3-33e2-4151-9e62-67300da1da6a/stuck-attempt.diff`.
