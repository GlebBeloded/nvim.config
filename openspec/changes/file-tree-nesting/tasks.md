## 0. Isolate earlier file-tree suites

Scenarios: `file-tree: Project tree opens on the left at width 35`, `file-tree: Project tree follows the current file`, `file-tree: Project tree a creates a file in the folder under the cursor`, `file-tree: Project tree add prompt matches the approved render`, `file-tree: Project tree matches the approved render`

- [x] 0.1 Make the shared file-tree test setup create a temporary `settings/file_tree.json` with `nesting.enabled = false`, call `settings.setup({ path = <temporary path> })`, and run `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="Project tree opens on the left at width 35"`; see it fail because the settings entry point does not exist
- [x] 0.2 Add the smallest typed `lua/gleb/file_tree/settings.lua` setup bootstrap needed by the helper, use it from the file-tree-view, file-tree-ops integration and screen suites, then run `make test CAPS=file-tree,picker` and see every earlier scenario pass unchanged

## 1a. Pattern rule syntax

Scenarios: `file-tree: Nesting rule nests by capture`, `file-tree: Nesting patterns match whole names`, `file-tree: Nesting captures are inserted literally`, `file-tree: Broken nesting rules are skipped`

- [x] 1a.1 Write the four cases in `tests/unit/file-tree/test_nesting.lua`, driving `require("gleb.file_tree.nesting").nest` with shipped `{ name, path, kind }` entries and captured `vim.notify`, then run `make test FILE=tests/unit/file-tree/test_nesting.lua CASE="Nesting rule nests by capture"` and see it fail
- [x] 1a.2 Add the typed pure engine in `lua/gleb/file_tree/nesting.lua`: whole-name Lua patterns, capture validation and literal substitution, with one WARN per broken rule per load
- [x] 1a.3 Run each scenario with `make test FILE=tests/unit/file-tree/test_nesting.lua CASE="<scenario title>"` and see it pass

## 1b. Rule precedence

Scenarios: `file-tree: Earlier nesting rule wins a shared child`, `file-tree: Nesting cycles keep rule order`, `file-tree: Folders never nest`

- [ ] 1b.1 Add the three cases to `tests/unit/file-tree/test_nesting.lua`, call the real `nest` entry point, and run `make test FILE=tests/unit/file-tree/test_nesting.lua CASE="Earlier nesting rule wins a shared child"`; see it fail
- [ ] 1b.2 Implement first-claim precedence, cycle rejection, chain lifting, file-only filtering and tree name order
- [ ] 1b.3 Run each scenario with `make test FILE=tests/unit/file-tree/test_nesting.lua CASE="<scenario title>"` and see it pass

## 1c. Nest cache and performance

Scenarios: `file-tree: Default nesting rules meet the large-folder bound`, `file-tree: Git redraw reuses the nest map`

- [ ] 1c.1 Add both cases to `tests/unit/file-tree/test_nesting.lua`, using the real 16-rule settings and a counting Lua rule through the real model draw path, then run `make test FILE=tests/unit/file-tree/test_nesting.lua CASE="Git redraw reuses the nest map"` and see it fail
- [ ] 1c.2 Cache by weak `fs.scan` table keys plus settings generation, bump generation on reload, and use a file-name hash for substituted children
- [ ] 1c.3 Run both cases with `make test FILE=tests/unit/file-tree/test_nesting.lua CASE="<scenario title>"` and see them pass, including the 5000-file ≤50 ms bound

## 2. Programmable rules

Scenarios: `file-tree: Lua nesting rule nests by function`, `file-tree: Failing Lua nesting rule is skipped`

- [ ] 2.1 Write both cases in `tests/unit/file-tree/test_nesting.lua` with `package.preload` modules and exact argument assertions, then run `make test FILE=tests/unit/file-tree/test_nesting.lua CASE="Lua nesting rule nests by function"` and see it fail
- [ ] 2.2 Compile `{ lua = <module> }` at its list position, validate returned names, catch load/call/type failures and continue with later rules
- [ ] 2.3 Run both cases with `make test FILE=tests/unit/file-tree/test_nesting.lua CASE="<scenario title>"` and see them pass

## 3. Default rules

Scenarios: `file-tree: Default nesting rules nest Go files`, `file-tree: Default nesting rules nest web files`, `file-tree: Default nesting rules nest Python and Rust files`, `file-tree: Default nesting rules nest project files`

- [ ] 3.1 Write the four cases in `tests/unit/file-tree/test_nesting.lua`, loading the real `settings/file_tree.json` through `require("gleb.file_tree.settings").load()`, then run `make test FILE=tests/unit/file-tree/test_nesting.lua CASE="Default nesting rules nest Go files"` and see it fail
- [ ] 3.2 Complete `lua/gleb/file_tree/settings.lua` validation and add `settings/file_tree.json` with Decision 5's ordered 16 rules, `nesting.enabled = true` and `ignore = []`
- [ ] 3.3 Run each scenario with `make test FILE=tests/unit/file-tree/test_nesting.lua CASE="<scenario title>"` and see it pass

## 4a. Rows, view state and refresh

Scenarios: `file-tree: Nests start collapsed under a chevron`, `file-tree: Nest children are indented under the parent`, `file-tree: Nest state survives a refresh`, `file-tree: Nest state is isolated between tabs`, `file-tree: Drawing prunes stale nest state`

- [ ] 4a.1 Extend `treeproj` in `tests/fixtures/build.sh` to Decision 8's exact manifest, write the five cases in `tests/integration/file-tree/test_nesting.lua` through `file_tree.toggle`, real `za`/`R` mappings and two real tabs, then run `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="Nests start collapsed under a chevron"` and see it fail
- [ ] 4a.2 Feed folder scans through the cached nest engine in `lua/gleb/file_tree/model.lua`, render parent chevrons and child indentation in `lua/gleb/file_tree/render.lua`, and keep/prune per-tab relative `expanded_nests` in `lua/gleb/file_tree/view.lua`
- [ ] 4a.3 Run each scenario with `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="<scenario title>"` and see it pass

## 4b. Invalid, disabled and reloaded settings

Scenarios: `file-tree: Invalid settings file disables nesting`, `file-tree: Nesting can be turned off`, `file-tree: Writing the settings file reloads nesting`, `file-tree: Writing settings through a normalized path reloads nesting`

- [ ] 4b.1 Write the four cases in `tests/integration/file-tree/test_nesting.lua` with real temporary JSON buffers and `:write`, including `/var` → `/private/var` path normalization, then run `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="Writing the settings file reloads nesting"` and see it fail
- [ ] 4b.2 Add the `gleb_file_tree_settings` `BufWritePost` path match through `fs.normalize`, generation bump and redraw; disable nesting safely on invalid or disabled settings
- [ ] 4b.3 Run each scenario with `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="<scenario title>"` and see it pass

## 4c. Nest-state clearing and migration

Scenarios: `file-tree: Fold all and reroot clear nest state`, `file-tree: Renaming a nest parent migrates its state`, `file-tree: Renaming a folder migrates nest state in every view`

- [ ] 4c.1 Write the three cases in `tests/integration/file-tree/test_nesting.lua`, driving real `zM`, cwd reroot and `r` across two tabs, then run `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="Renaming a folder migrates nest state in every view"` and see it fail
- [ ] 4c.2 Clear `expanded_nests` on fold-all and reroot, never pass it to `expanded.lua`, and migrate file/folder keys in every view of the moved root
- [ ] 4c.3 Run each scenario with `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="<scenario title>"` and see it pass

## 5a. Nest keys and row cap

Scenarios: `file-tree: za toggles a nest`, `file-tree: h on a nested file closes its nest`, `file-tree: Enter on a nest parent opens the file`, `file-tree: Fold all and unfold all include nests`, `file-tree: Unfold all counts nested children toward the row limit`

- [ ] 5a.1 Write the five cases in `tests/integration/file-tree/test_nesting.lua`, driving real `za`, `h`, `<CR>`, `zR` and `zM` mappings on populated rows, then run `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="za toggles a nest"` and see it fail
- [ ] 5a.2 Extend the existing fold actions for parent/child nest rows and count visible nest children in both 5000-row guards while keeping open separate from expansion
- [ ] 5a.3 Run each scenario with `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="<scenario title>"` and see it pass

## 5b. Follow, reveal and ops interplay

Scenarios: `file-tree: Followed nested file expands its nest`, `file-tree: Added nested file is revealed in its nest`, `file-tree: Renamed file is revealed in a collapsed nest`, `file-tree: Pasted file is revealed in a collapsed nest`, `file-tree: Following under a symlinked root expands the nest`

- [ ] 5b.1 Write the five cases in `tests/integration/file-tree/test_nesting.lua`, driving the real editor follow, reveal, add, `r` and `p` entry points with populated data and normalized paths, then run `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="Followed nested file expands its nest"` and see it fail
- [ ] 5b.2 Add one `select_path(path)` helper that normalizes the path, expands folders and its nest, then selects it; use it from follow, reveal, add, rename and paste, with a child row targeting `dirname(row.path)`
- [ ] 5b.3 Run each scenario with `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="<scenario title>"` and see it pass

## 5c. Parent operation safety

Scenarios: `file-tree: Deleting a nest parent keeps its children`, `file-tree: Visual delete on a collapsed parent deletes only the parent`

- [ ] 5c.1 Write both cases in `tests/integration/file-tree/test_nesting.lua`, driving the real `d` mapping and confirmation on a populated fixture, then run `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="Visual delete on a collapsed parent deletes only the parent"` and see it fail
- [ ] 5c.2 Keep visual selection row-based and make delete operate only on each selected row path, never implied nest children
- [ ] 5c.3 Run both cases with `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="<scenario title>"` and see them pass

## 5d. Existing fold behavior includes nests

Scenarios: `file-tree: Project tree za on a file collapses its folder`, `file-tree: Project tree zM collapses every folder`, `file-tree: Project tree zR expands every folder`, `file-tree: Project tree unfold all stops at the row limit`

- [ ] 5d.1 Update the four existing cases in `tests/integration/file-tree/test_project_tree.lua` to assert the modified requirement through real `za`, `zM` and `zR`, then run `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="Project tree za on a file collapses its folder"` and see it fail
- [ ] 5d.2 Make the existing fold actions include nests without changing plain-file, folder, cursor-placement or warning behavior
- [ ] 5d.3 Run each scenario with `make test FILE=tests/integration/file-tree/test_project_tree.lua CASE="<scenario title>"` and see it pass

## 6. Git tint

Scenarios: `file-tree: Collapsed nest parent shows a changed child`, `file-tree: Nest parent keeps its own status`, `file-tree: Deleted unlisted child does not tint its parent`

- [ ] 6.1 Write the three cases in `tests/integration/file-tree/test_nesting.lua` with fresh fixture copies and assert real name extmark groups, then run `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="Collapsed nest parent shows a changed child"` and see it fail
- [ ] 6.2 Share `folder_status`'s strength helper and renamed/deleted → modified folding with listed nest children; prefer the parent's own status and ignore absent children
- [ ] 6.3 Run each scenario with `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="<scenario title>"` and see it pass

## 7. Approved screen

Scenarios: `file-tree: File tree nests match the approved render`

- [ ] 7.1 Write `tests/screen/file-tree/test_nesting.lua` at 100x30 through the real tree and fixture, compare text verbatim with byte-identical `tests/screen/file-tree/nest_proposed.ansi`, and assert real extmark groups; run `make test FILE=tests/screen/file-tree/test_nesting.lua CASE="File tree nests match the approved render"` and see it fail
- [ ] 7.2 Make the render match, compare `make render CASE=nest_proposed` with `make colorize FILE=openspec/changes/file-tree-nesting/design.md`, then run the same targeted test and see it pass
- [ ] 7.3 Run `make check`
