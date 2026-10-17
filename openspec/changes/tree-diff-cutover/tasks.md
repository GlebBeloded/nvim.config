## 1. Keys

Scenarios: `keymaps: Alt-e reveals current file`, `keymaps: Alt-e on URI buffer focuses the project tree`, `keymaps: Alt-e tolerates a deleted current file`, `keymaps: Alt-e closes the focused project tree`, `keymaps: Alt-G replaces the project tree with the changes panel`, `keymaps: Alt-G closes the focused changes panel`, `keymaps: Alt-g opens the changes review`, `keymaps: Toggle wins over a pending tree refresh`, `keymaps: Toggle wins over a pending changes refresh`, `keymaps: Command maps do not enter the command line`, `file-tree: Toggle tolerates a deleted current file`, `file-tree: Project tree opens on the left at width 35`, `file-tree: Project tree toggle closes a focused tree`, `file-tree: Project tree toggle focuses an open tree`, `file-tree: Project tree closes with the last window`

- [ ] 1.1 Rewrite the toggle cases of `tests/integration/keymaps/test_keymaps.lua` to the scenarios above (delete the cases of `Alt-e on URI buffer focuses filesystem`, `Alt-e closes focused filesystem tree`, `Alt-G switches tree to git status`, `Alt-G closes focused git status tree`, `Alt-g opens Differ`, `Toggle wins over pending filesystem render`), move `Toggle tolerates a deleted current file` to the project tree, delete the `file-tree: Project tree actions start unbound` case, and see the new cases fail
- [ ] 1.2 In `settings/keymap.json` remove `tree.toggle_filesystem`, `tree.toggle_git_status`, `git.open_differ` and add `file_tree.toggle` `["<A-e>"]`, `changes.toggle` `["<A-G>"]`, `changes.review` `["<A-g>"]`; make `file_tree.toggle` reveal the current file when it opens the tree (design Decision 2)
- [ ] 1.3 Edit the `## Shortcut table` of `openspec/specs/shortcuts/spec.md`: Cmd+E → `file_tree.toggle`, Cmd+G → `changes.review` (design Decision 9); run `make chain` and `make stack`
- [ ] 1.4 Run `make test FILE=tests/integration/keymaps/test_keymaps.lua` and the file-tree window cases and see them pass

## 2. Directory buffers

Scenarios: `file-tree: Directory argument opens the project tree`, `file-tree: netrw is not loaded`

- [ ] 2.1 Write both scenarios in `tests/integration/file-tree/test_project_hijack.lua`, delete the neo-tree case `Directory argument opens tree in current window`, and see them fail
- [ ] 2.2 Add `netrwPlugin` to lazy.nvim's `performance.rtp.disabled_plugins` and the `gleb_file_tree_hijack` `BufEnter` autocmd (design Decision 4; add a `root` option to the tree's open if `file-tree-view` has none)
- [ ] 2.3 Run the file and see it pass

## 3. Changes review workflow (e2e)

Scenarios: `git: Cmd+G opens the changes review of a dirty repo`, `git: ]f steps to the next changed file in the changes review`, `git: ]c steps to the next change in the changes review`

- [ ] 3.1 Port `tests/e2e/git/test_differ_review.lua` to `tests/e2e/git/test_changes_review.lua` (same `dirty` fixture and manifest, the panel rows and the diff view instead of differ's panel and winbar), delete the old file, and see it fail under `make e2e`
- [ ] 3.2 Nothing to implement beyond tasks 1 and 5; run `make e2e CASE="changes review"` and see it pass

## 4. Bufferline

Scenarios: `bufferline: tabs start after the open project tree`, `bufferline: tabs start after the open changes panel`, `bufferline: tabline over the changes panel matches the approved render`, `bufferline: tabline with tree open matches reference screenshot`, `bufferline: tabline without tree matches reference screenshot`

- [ ] 4.1 Switch `tests/screen/bufferline/test_bufferline_screen.lua` from `:Neotree` to `file_tree.toggle`, add the changes panel cases (mask and legend of design.md "Proposed — tabline over the changes panel"), and see them fail
- [ ] 4.2 Replace the `neo-tree` offset in `lua/gleb/bufferline.lua` by `gleb-changes` beside `gleb-file-tree` (design Decision 8)
- [ ] 4.3 Run the file, review and commit the regenerated reference screenshots

## 5. Remove neo-tree, differ and codediff

Scenarios: `git: Missing optional git plugins are tolerated`, `git: Git commands are available after startup`, `git: Removed diff plugins are not registered`, `git: Diffview mappings come from git actions`, `git: Diffview conflict choices come from git actions`, `actions: Every configured mapping is action-owned`, `actions: Plugin-window mappings are action-owned`, `actions: Unconfigured defaults are absent`, `actions: Lazy specs define no shortcut keys`

- [ ] 5.1 Update `tests/unit/git/test_modules.lua`, `tests/integration/git/test_git.lua` and `tests/integration/actions/{test_plugin_ownership,test_adapters}.lua` to the scenarios above; delete the cases of every removed scenario of design.md "Removed scenarios" with their files (`tests/integration/file-tree/{test_tree,test_stage,test_diff_preview,test_tree_icons}.lua`, `tests/unit/file-tree/test_diff_preview_state.lua`, `tests/screen/file-tree/{test_tree_screen,test_git_status_help}.lua` and their screenshots) after checking each successor case exists; see the updated cases fail
- [ ] 5.2 Remove the plugin specs and `lazy-lock.json` entries of neo-tree.nvim, differ.nvim and vscode-diff.nvim; keep nui.nvim's own entry; reword diffview's comment (design Decision 5)
- [ ] 5.3 Remove the code of design Decision 6 and the 31 `settings/keymap.json` entries of Decision 7
- [ ] 5.4 Point the Find Action adapter fixture of `tests/integration/find-action/test_assign.lua` and the rows/registry unit tests at remaining ids; drop `vscode-diff.nvim` from `tests/bootstrap.sh` and `tests/types.sh`; replace the `neo-tree` render case with `project-tree` and add `changes` (`billing` fixture) in `tests/render/cases.lua`; reword the `dirty` comment in `tests/fixtures/build.sh`
- [ ] 5.5 Run `make test` and `make types` and see them pass; `grep -rn "neo-tree\|neo_tree\|differ\|codediff\|vscode.diff\|diff_preview" lua/ settings/ tests/ init.lua` lists only the loop's async wording (out of scope)

## 6. Docs and spec text

- [ ] 6.1 Update docs/architecture.md and docs/testing.md (design Decision 12) and the `## Purpose` lines of `openspec/specs/file-tree/spec.md` and `openspec/specs/git/spec.md` (Decision 9)
- [ ] 6.2 `make specs` passes

## 7. Gate

- [ ] 7.1 `make trace` reports no orphans and every scenario of this change as tested
- [ ] 7.2 `make check E2E=1` is green; `openspec validate tree-diff-cutover --strict` passes; `python3 .archon/scripts/pinned.py tree-diff-cutover` prints `none`
