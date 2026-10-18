## 1. Cut over the core keys
Scenarios: `keymaps: Alt-e reveals current file`, `keymaps: Alt-e on URI buffer focuses the project tree`, `keymaps: Alt-e tolerates a deleted current file`, `keymaps: Alt-G replaces the project tree with the changes panel`, `keymaps: Alt-g opens the changes review`
- [x] 1.1 Rewrite these cases in `tests/integration/keymaps/test_keymaps.lua`, drive the real normal-mode mappings against populated project-tree and changes-panel data, and run `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="Alt-e reveals current file"` to see the cutover fail
- [x] 1.2 Bind `<A-e>` to `file_tree.toggle`, `<A-G>` to `changes.toggle` and `<A-g>` to `changes.review` in `settings/keymap.json`; make the project-tree toggle reveal an eligible current file and use the integration async wait budget for the review diff
- [x] 1.3 Edit the Cmd+E and Cmd+G rows of `openspec/specs/shortcuts/spec.md`, run `make chain` and `make stack`, then run the five cases and see them pass
- [x] 1.4 Commit the key rebinding separately from plugin removal so it can be rolled back independently

## 2. Keep toggles and the core mapping table coherent
Scenarios: `keymaps: Alt-e closes the focused project tree`, `keymaps: Alt-G closes the focused changes panel`, `keymaps: Toggle wins over a pending tree refresh`, `keymaps: Toggle wins over a pending changes refresh`, `keymaps: Core mappings resolve through actions`
- [x] 2.1 Replace the retired neo-tree toggle cases and extend the real-lhs table in `tests/integration/keymaps/test_keymaps.lua`; run `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="Toggle wins over a pending tree refresh"` and see it fail
- [x] 2.2 Make pending project-tree and changes-panel work respect a close, and update action registration so every moved key resolves through its new action id
- [x] 2.3 Run the five named cases and `keymaps: Command maps do not enter the command line` and see them pass

## 3. Hijack directory buffers
Scenarios: `file-tree: Directory argument opens the project tree`, `file-tree: netrw is not loaded`, `file-tree: Directory buffer focuses an open project tree`
- [ ] 3.1 Write the three cases in `tests/integration/file-tree/test_project_hijack.lua` using `:edit <dir>` and an already populated project tree; run `make test FILE=tests/integration/file-tree/test_project_hijack.lua CASE="Directory argument opens the project tree"` and see it fail
- [ ] 3.2 Add `netrwPlugin` to `lua/gleb/plugins/init.lua`'s lazy.nvim `disabled_plugins` and add the `gleb_file_tree_hijack` `BufEnter` autocmd: only a newly opened tree takes the directory as root; an existing tree is focused without changing root or cursor
- [ ] 3.3 Run `make test FILE=tests/integration/file-tree/test_project_hijack.lua` and see it pass

## 4a. Retain the project-tree sidebar contract
Scenarios: `file-tree: Project tree opens on the left at width 35`, `file-tree: Project tree toggle closes a focused tree`, `file-tree: Project tree toggle focuses an open tree`, `file-tree: Project tree closes with the last window`, `file-tree: Project tree toggle reveals the current file`
- [ ] 4a.1 Update `tests/integration/file-tree/test_project_tree.lua` to exercise the real `file_tree.toggle` action after the binding cutover; run `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="Project tree toggle reveals the current file"` and see it fail
- [ ] 4a.2 Make the smallest `lua/gleb/file_tree/` changes needed to preserve all five sidebar behaviours without neo-tree
- [ ] 4a.3 Run the five named cases and see them pass

## 4b. Replace neo-tree in editor-window hygiene
Scenarios: `file-tree: Project tree opening skips non-editor windows`, `file-tree: A file cannot replace the project tree buffer`, `file-tree: Project tree split windows keep editor options`, `file-tree: Project tree tab windows keep editor options`
- [ ] 4b.1 Change the two `:Neotree` setups in `tests/integration/file-tree/test_project_tree.lua` to a populated changes panel and run `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="Project tree opening skips non-editor windows"` to see the old `file_tree/view.lua` filter fail
- [ ] 4b.2 Replace the neo-tree exclusions at the current `lua/gleb/file_tree/view.lua` call sites with changes-panel exclusions while preserving quickfix, terminal, floating and diff-view handling
- [ ] 4b.3 Run the four named cases and see them pass

## 4c. Replace neo-tree in follow and close isolation
Scenarios: `file-tree: Project tree opens from non-project buffers`, `file-tree: Project tree does not follow a directory buffer`, `file-tree: Project tree closes before last editor with close`, `file-tree: Project tree and changes panel close before the last editor`
- [ ] 4c.1 Tighten `tests/integration/file-tree/test_project_live.lua` and `test_project_tree.lua` to preserve root and cursor for a directory buffer and to use a real changes panel in the close-if-last case; run `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="Project tree and changes panel close before the last editor"` and see it fail
- [ ] 4c.2 Update project-tree follow and QuitPre handling to treat directory buffers as non-followable and the changes panel as the other sidebar
- [ ] 4c.3 Run the four named cases and see them pass

## 5a. Update git and action retirement tests
Scenarios: `git: Missing optional git plugins are tolerated`, `git: Git commands are available after startup`, `git: Removed diff plugins are not registered`, `actions: Every configured mapping is action-owned`, `actions: Plugin-window mappings are action-owned`
- [ ] 5a.1 Update `tests/unit/git/test_modules.lua`, `tests/integration/git/test_git.lua` and `tests/integration/actions/{test_ownership,test_plugin_ownership,test_adapters}.lua` to assert the retired commands, plugins, adapters and mappings are absent; run `make test FILE=tests/integration/git/test_git.lua CASE="Removed diff plugins are not registered"` and see it fail
- [ ] 5a.2 Keep the tests on real populated project-tree, changes-panel, diff-view and diffview windows and remove only expectations for neo-tree, differ and codediff
- [ ] 5a.3 Run the five named cases and see them pass after tasks 5c and 5d

## 5b. Remove retired file-tree tests only after successor checks
Scenarios: `file-tree: Project tree v opens a vertical split`, `file-tree: Project tree t opens a new tab`, `file-tree: Project tree rows have icons and no guides`, `file-tree: Project tree matches the approved render`, `git: Changes panel Space stages an unstaged file`
- [ ] 5b.1 Run each successor named in design.md's 78-row Removed scenarios table, starting with `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="Project tree v opens a vertical split"`; record and fix any missing successor before deleting a retired case
- [ ] 5b.2 After every successor passes, delete the retired cases from `tests/integration/file-tree/{test_tree,test_stage,test_diff_preview,test_tree_icons}.lua`, `tests/unit/file-tree/test_diff_preview_state.lua`, and `tests/screen/file-tree/{test_tree_screen,test_git_status_help}.lua`; delete a file and its screenshots when its last case is removed, never leave an empty test file
- [ ] 5b.3 Confirm the five named successor cases still pass

## 5c. Remove neo-tree implementation and colours
Scenarios: `file-tree: Project tree keys come from the keymap file`, `file-tree: Project tree rows have icons and no guides`, `file-tree: Project tree colours renamed and conflicted files`, `file-tree: Project tree matches the approved render`, `file-tree: Project tree opens from non-project buffers`
- [ ] 5c.1 Extend the named project-tree tests to reject neo-tree mappings, highlights and windows, run `make test FILE=tests/screen/file-tree/test_project_tree.lua CASE="Project tree matches the approved render"`, and see the legacy surface fail the new assertion
- [ ] 5c.2 Remove `lua/gleb/file_tree/{neo_tree,diff_preview}.lua`, retired neo-tree/tree actions, the neo-tree block from `lua/gleb/colors/gruvbox-material/git.lua`, NeoTree highlights from `lua/gleb/colors/gruvbox-material/init.lua`, and `NeoTree` handling from `lua/gleb/colors/transparency.lua`
- [ ] 5c.3 Run the five named cases and see them pass

## 5d. Remove differ, codediff and plugin wiring
Scenarios: `git: Removed diff plugins are not registered`, `git: Diffview mappings come from git actions`, `git: Diffview conflict choices come from git actions`, `actions: Unconfigured defaults are absent`, `actions: Lazy specs define no shortcut keys`
- [ ] 5d.1 Update the named tests to assert only diffview mappings remain and run `make test FILE=tests/integration/git/test_git.lua CASE="Diffview mappings come from git actions"` to see the legacy adapters/defaults fail
- [ ] 5d.2 Remove the three plugin specs and lock entries; remove `lua/gleb/git/{differ,vscode_diff}.lua`, their actions, `lua/gleb/actions/adapters/{neo_tree,differ,codediff}.lua`, `neo_tree_scope`, the codediff audit allowlist and retired adapter assignments; remove the remaining 31 retired `settings/keymap.json` entries while keeping diffview, gitsigns and nui.nvim
- [ ] 5d.3 Run the five named cases and see them pass, then commit plugin removal separately from task 1

## 5e. Move Find Action fixtures to remaining actions
Scenarios: `find-action: Adapter assignment reports deferred application`, `find-action: Saved shortcut applies immediately`, `find-action: Catalog rows use standalone Title Case labels`
- [ ] 5e.1 Update `tests/integration/find-action/test_assign.lua` and `test_run.lua` catalog tables so the `neo_tree.open` fixture uses a remaining `lazy.*` adapter id and ordinary `file_tree.*`/`changes.*` actions apply immediately; run `make test FILE=tests/integration/find-action/test_assign.lua CASE="Adapter assignment reports deferred application"` and see the stale fixture fail
- [ ] 5e.2 Remove retired adapter names from `lua/gleb/find_action/assign.lua`
- [ ] 5e.3 Run the three named cases and see them pass

## 5e2. Preserve Find Action screenshots
Scenarios: `find-action: Wide palette matches reference screenshots`, `find-action: Compact palette matches reference screenshot`, `find-action: Narrow palette matches reference screenshot`, `find-action: Conflict assignment matches reference screenshot`, `find-action: Free assignment matches reference screenshot`
- [ ] 5e2.1 Replace removed actions in `tests/screen/find-action/test_palette.lua` with stand-in actions having the same displayed titles, run `make test FILE=tests/screen/find-action/test_palette.lua CASE="Wide palette matches reference screenshots"`, and see the stale plugin setup fail
- [ ] 5e2.2 Remove neo-tree from the screen test's plugin startup and keep all five stored screenshots byte-identical
- [ ] 5e2.3 Run `make test FILE=tests/screen/find-action/test_palette.lua` and see all five cases pass without re-approving screenshots

## 5f. Remove retired tooling and render fixtures
Scenarios: `git: Removed diff plugins are not registered`, `file-tree: Project tree matches the approved render`, `git: Changes panel matches the approved render`
- [ ] 5f.1 Tighten the plugin/bootstrap and render assertions, run `make test FILE=tests/screen/git/test_changes_screen.lua CASE="Changes panel matches the approved render"`, and see the missing post-cutover render setup fail
- [ ] 5f.2 Drop vscode-diff.nvim from `tests/bootstrap.sh` and `tests/types.sh`; replace the `neo-tree` render case with `project-tree`, add `changes` using the `billing` fixture in `tests/render/cases.lua`, and reword the `dirty` fixture comment in `tests/fixtures/build.sh`
- [ ] 5f.3 Run `make deps`, `make types`, and the three named render/screen cases and see them pass

## 6. Offset bufferline over either owned sidebar
Scenarios: `bufferline: tabs start after the open project tree`, `bufferline: tabs start after the open changes panel`, `bufferline: tabline over the changes panel matches the approved render`, `bufferline: tabline with tree open matches reference screenshot`, `bufferline: tabline without tree matches reference screenshot`
- [ ] 6.1 Update `tests/screen/bufferline/test_bufferline_screen.lua` to use real `file_tree.toggle` and `changes.toggle` actions; add the changes-panel case with real extmark highlight groups and a byte-identical `.ansi` copy under `tests/screen/bufferline/`, then run `make test FILE=tests/screen/bufferline/test_bufferline_screen.lua CASE="tabline over the changes panel matches the approved render"` and see it fail
- [ ] 6.2 Replace the `neo-tree` offset in `lua/gleb/bufferline.lua` with `gleb-changes` beside `gleb-file-tree`
- [ ] 6.3 Run all five cases; keep the existing project-tree screenshots unchanged and do not re-approve anything during the test run

## 7. Port the physical changes-review workflow
Scenarios: `git: Cmd+G opens the changes review of a dirty repo`, `git: ]f steps to the next changed file in the changes review`, `git: ]c steps to the next change in the changes review`
- [ ] 7.1 Only after task 5d, port `tests/e2e/git/test_differ_review.lua` to `tests/e2e/git/test_changes_review.lua` using the same `dirty` fixture and manifest, real Cmd+G/`]f`/`]c` key events, panel rows and owned diff view; run `make e2e CASE="changes review"` and see it fail
- [ ] 7.2 Delete the old e2e file after its replacement exists; use the harness async wait budget rather than a 100 ms wait
- [ ] 7.3 Run `make e2e CASE="changes review"` and see all three scenarios pass

## 8. Update architecture and retained spec text
Scenarios: `shortcuts: Shortcut table names action ids`, `shortcuts: Shortcut meanings survive registry migration`, `find-action: Saved shortcut applies immediately`
- [ ] 8.1 Run `make test FILE=tests/integration/find-action/test_assign.lua CASE="Saved shortcut applies immediately"` and the shortcut gates before editing, then update docs/architecture.md's module map, startup/plugin wiring and decisions plus a Moved keys note (`H`→`I`, `?`→Find Action, `<`/`>`→Alt+E/Alt+Shift+G); update only the `file-tree` and `git` Purpose lines and leave `docs/testing.md:81` to the loop-wording fix
- [ ] 8.2 Run the named case, `make chain`, `make stack` and `make specs` and see them pass

## 9. Run the cutover gates
Scenarios: `diff: Diff view opens on the current file`, `diff: Diff view mappings come from diff actions`, `diff: Diff view checkboxes follow the index`, `diff: Diff view marks both ends of a moved block`, `diff: Diff view moved block matches the approved render`
- [ ] 9.1 Run `make trace VERBOSE=1` and confirm no orphans, duplicates or missing scenarios introduced by this change
- [ ] 9.2 Run `rg -n 'neo-tree|neo_tree|NeoTree|Neotree|differ\.|Differ|codediff|vscode\.diff|diff_preview|open_differ' lua settings tests init.lua -g '!tests/unit/loop/**'`; remove every hit except an explicitly retained diffview/gitsigns/nui reference covered by the proposal
- [ ] 9.3 Run `make check E2E=1`, `openspec validate tree-diff-cutover --strict`, and `python3 .archon/scripts/pinned.py tree-diff-cutover`; require the pinned command to print `none`

## Agent decisions

- Kept the existing tree identity guards and changes timer cleanup because the replacement race tests showed they already preserve a close; task 2 only needed the retired tests and action table updated.

## Stuck

- Task 3: the red integration test is committed, but the existing-tree cursor case still fails after two production attempts. Attempt 1 added the netrw disablement and a synchronous directory `BufEnter` hijack with an explicit root for a new tree; the new-tree case passed, while the populated existing tree moved from `go.mod`. Attempt 2 put an empty buffer in the directory's editor window before focusing the existing tree and guarded the per-view callback from the wiped buffer; the populated-tree case still moved from `go.mod`. The corrected sandbox probe with a committed git root reported `before = 3`, `after = 3`, `line = "go.mod"`, `current_is_tree = true`, and the original root, while the `treeproj` integration fixture still fails the same cursor assertion after its initial draw timer is nil. The second production attempt is saved at `/Users/hlebbeladzed/.archon/workspaces/GlebBeloded/nvim.config/artifacts/runs/3f6b4fd0-a502-433d-b01e-a9323b75d5c1/stuck-attempt-3.diff`; production edits were reverted.
