## 1a. Picker input core
Scenarios: `picker: Input prompt submits its query`, `picker: Input prompt starts with its default and previews it`, `picker: Input prompt cancels with Esc`, `picker: Input prompt ignores a blank query`
- [x] 1a.1 Write the tests in `tests/integration/picker/test_input.lua`, drive the real input picker with typed keys, and see them fail
- [x] 1a.2 Add typed `lua/gleb/picker/input.lua` on the shared frame with a live preview row and deferred submit
- [x] 1a.3 Run `make test FILE=tests/integration/picker/test_input.lua` and see them pass

## 1b. Picker teardown
Scenarios: `picker: Input prompt Esc restores tree focus and cursor state`, `picker: Input prompt submits after the picker closes`
- [x] 1b.1 Write the tests in `tests/integration/picker/test_input.lua`, open the real prompt from a populated project tree, press `<Esc>` or `<CR>`, and see them fail
- [x] 1b.2 Restore the originating window and `guicursor` after teardown, and schedule `on_submit` only after the picker closes
- [x] 1b.3 Run `make test FILE=tests/integration/picker/test_input.lua` and see them pass

## 2. Pure path and selection helpers
Scenarios: `file-tree: Project tree a creates a file in the folder under the cursor`, `file-tree: Project tree refuses operations on the root row`, `file-tree: Project tree refuses a path that escapes the root`, `file-tree: Project tree move preflights the whole batch`, `file-tree: Project tree refuses a cross-device move`
- [x] 2.1 Write the scenario-backed units in `tests/unit/file-tree/test_paths.lua` for root/folder/compact/file targets, normalized containment, nested-selection dedupe, batch preflight and device checks, and see them fail
- [x] 2.2 Add pure `lua/gleb/file_tree/paths.lua` helpers (`target_folder`, `copy_name`, `is_inside`, `dedupe`, preflight helpers) with no plugin requires
- [x] 2.3 Run `make test FILE=tests/unit/file-tree/test_paths.lua` and see them pass

## 3a. Create operations
Scenarios: `file-tree: Project tree a creates a file in the folder under the cursor`, `file-tree: Project tree a on a file creates next to it`, `file-tree: Project tree a with a trailing slash creates a folder`, `file-tree: Project tree a creates missing parent folders`, `file-tree: Project tree a reports an existing name`
- [x] 3a.1 Write the tests in `tests/integration/file-tree/test_project_ops.lua`, drive `a` in a real populated project tree on a fresh `treeproj` copy, and see them fail
- [x] 3a.2 Add `file_tree.add` in `ops.lua` and `actions.lua`, select created paths through `view.lua`, and add the `a` key in `settings/keymap.json` with no action `plugin`
- [x] 3a.3 Run `make test FILE=tests/integration/file-tree/test_project_ops.lua CASE="Project tree a"` and see them pass

## 3b. Create safety and operation keys
Scenarios: `file-tree: Project tree create reports a read-only destination`, `file-tree: Project tree operation keys come from the keymap file`, `file-tree: Project tree refuses operations on the root row`, `file-tree: Project tree Visual operations refuse the root row`, `file-tree: Project tree add prompt matches the approved render`
- [x] 3b.1 Write the integration assertions in `tests/integration/file-tree/test_project_ops.lua` and the screen case in `tests/screen/file-tree/test_project_ops.lua`, drive the real `a`, `r`, `d`, `c` and `x` mappings in Normal and Visual modes plus the key applicator, and see them fail
- [x] 3b.2 Validate normalized destinations, report create failures, and register `a`, `r`, `d`, `c`, `x`, `p`, `R` plus Visual `d`, `c`, `x` from `settings/keymap.json`, with no action `plugin`
- [x] 3b.3 Run `make test FILE=tests/integration/file-tree/test_project_ops.lua CASE="Project tree"` and `make test FILE=tests/screen/file-tree/test_project_ops.lua CASE="Project tree add prompt matches the approved render"` and see them pass

## 4a. LSP file operations
Scenarios: `file-tree: Project tree rename asks language servers to update references`, `file-tree: Project tree rename skips servers whose filters do not match`, `file-tree: Project tree rename waits for servers at most one second`, `file-tree: Project tree move notifies didRename only after the target exists`
- [x] 4a.1 Write `tests/integration/file-tree/test_project_lsp_rename.lua` with an in-process `vim.lsp.start` server whose `cmd` function records real requests, plus `tests/unit/file-tree/test_paths.lua` filter units for `**/*.go`, `**/*.{ts,tsx}`, `ignoreCase` and folder matches; drive `r` and see them fail
- [x] 4a.2 Add typed `lua/gleb/file_tree/lsp_files.lua` with filter matching, one ≤1000 ms batched willRename exchange, workspace-edit application, late-response rejection and post-stat didRename notification
- [x] 4a.3 Run `make test FILE=tests/integration/file-tree/test_project_lsp_rename.lua` and `make test FILE=tests/unit/file-tree/test_paths.lua` and see them pass

## 4b. Rename and move preflight
Scenarios: `file-tree: Project tree r renames a file and its buffer`, `file-tree: Project tree r renames a folder and the buffers inside`, `file-tree: Project tree r reports an existing name`, `file-tree: Project tree rename refuses a vanished row`, `file-tree: Project tree move preflights the whole batch`
- [x] 4b.1 Write the tests in `tests/integration/file-tree/test_project_ops.lua`, drive `r` and Visual cut/paste against populated data, and see them fail before any partial move or LSP traffic
- [x] 4b.2 Add `ops.move(pairs)` with complete lstat, case-insensitive target, normalized-root, same-device and root-row preflight before LSP, then move, post-stat and one refresh per root view
- [x] 4b.3 Run `make test FILE=tests/integration/file-tree/test_project_ops.lua CASE="Project tree rename"` and see them pass

## 4c. Rename identity and filesystem edge cases
Scenarios: `file-tree: Project tree rename reports a read-only destination`, `file-tree: Project tree supports a case-only rename`, `file-tree: Project tree rename follows a buffer opened through a symlinked root`, `file-tree: Project tree rename moves a symlink and not its target`, `file-tree: Project tree folder rename migrates expanded keys`, `file-tree: Project tree refuses a cross-device move`
- [x] 4c.1 Write the tests in `tests/integration/file-tree/test_project_ops.lua` and device preflight unit in `tests/unit/file-tree/test_paths.lua`, drive real renames on populated data, and see them fail
- [x] 4c.2 Move case-only names through a temporary sibling, match buffers by realpath, migrate expanded keys, preserve failures atomically and report cross-device exactly
- [x] 4c.3 Run `make test FILE=tests/integration/file-tree/test_project_ops.lua CASE="Project tree"` and `make test FILE=tests/unit/file-tree/test_paths.lua` and see them pass

## 5a. Delete selection and confirmation
Scenarios: `file-tree: Project tree d moves a file to the Trash after confirmation`, `file-tree: Project tree d keeps the file when cancelled`, `file-tree: Project tree Visual d deletes every selected row`, `file-tree: Project tree d deletes without a trash command`, `file-tree: Project tree d closes buffers of deleted files`
- [x] 5a.1 Write the tests in `tests/integration/file-tree/test_project_ops.lua`, override `ops.state.trash_path` with a recording fake while driving the real `d` mapping and picker confirmation, and see them fail
- [x] 5a.2 Add normal/Visual `file_tree.delete`, fixed `/usr/bin/trash -s` selection with test override, recursive fallback only when trash is unavailable, and cross-tab unmodified-buffer cleanup that keeps windows
- [x] 5a.3 Run `make test FILE=tests/integration/file-tree/test_project_ops.lua CASE="Project tree d"` and see them pass

## 5b. Delete failure and path safety
Scenarios: `file-tree: Project tree d reports a failed delete`, `file-tree: Project tree delete refuses a vanished row safely`, `file-tree: Project tree fallback delete reports a read-only destination`, `file-tree: Project tree delete removes a symlink and not its target`, `file-tree: Project tree trash failure never falls back to permanent delete`
- [x] 5b.1 Write the tests in `tests/integration/file-tree/test_project_ops.lua`, use the module-state trash override and real lstat paths, drive `d`, and see them fail
- [x] 5b.2 Delete row paths without resolving symlinks, treat vanished rows as gone, preserve paths on trash/fallback failure, and never invoke permanent deletion after trash starts
- [x] 5b.3 Run `make test FILE=tests/integration/file-tree/test_project_ops.lua CASE="Project tree delete"` and see them pass

## 5c. Delete modified-buffer safety
Scenarios: `file-tree: Project tree delete does not let auto-save resurrect a file`, `file-tree: Project tree delete preserves windows across tabs`
- [x] 5c.1 Write the tests in `tests/integration/file-tree/test_project_ops.lua`, populate buffers in two tabs and run the real auto-save event after `d`, and see them fail
- [x] 5c.2 Count unsaved buffers in confirmation, retain modified buffers, make `should_autosave` skip absent files, and ensure fallback buffers are never deleted paths
- [x] 5c.3 Run `make test FILE=tests/integration/file-tree/test_project_ops.lua CASE="Project tree delete"` and see them pass

## 6a. Copy and paste conflicts
Scenarios: `file-tree: Project tree c and p copy a file into another folder`, `file-tree: Project tree pasting a copy over an existing name asks for a new name`, `file-tree: Project tree c and p copy a folder recursively`, `file-tree: Project tree copy conflict advances to copy2`, `file-tree: Project tree folder copy preflights before writing`
- [x] 6a.1 Write the tests in `tests/integration/file-tree/test_project_ops.lua`, drive real `c`, `p` and the Copy picker on populated trees, and see them fail
- [x] 6a.2 Add recursive copy with complete destination preflight and conflict names `_copy`, `_copy2`, continuing upward without overwrites
- [x] 6a.3 Run `make test FILE=tests/integration/file-tree/test_project_ops.lua CASE="Project tree c and p"` and see them pass

## 6b. Cut and move safety
Scenarios: `file-tree: Project tree x and p move a file like a rename`, `file-tree: Project tree refuses to paste a folder into itself`, `file-tree: Project tree Visual c copies every selected row`, `file-tree: Project tree cut refuses an existing target name`, `file-tree: Project tree cut into its current parent is a no-op`
- [x] 6b.1 Write the tests in `tests/integration/file-tree/test_project_ops.lua`, drive normal and Visual `x`, `c`, `p` on populated trees, and see them fail
- [x] 6b.2 Route cuts through `ops.move`, reject self-paste and existing targets, make same-parent cuts no-ops, deduplicate Visual selections and clear cut state after paste
- [x] 6b.3 Run `make test FILE=tests/integration/file-tree/test_project_ops.lua CASE="Project tree"` and see them pass

## 6c. Symlinks, missing clipboard entries and refresh
Scenarios: `file-tree: Project tree folder copy recreates symlinks`, `file-tree: Project tree paste continues after a missing clipboard path`, `file-tree: Project tree R picks up changes at once`, `file-tree: Project tree R starts at least one git status run`, `file-tree: Project tree R preserves another tab's tree state`
- [x] 6c.1 Write the tests in `tests/integration/file-tree/test_project_ops.lua`, drive real `c`, `p` and `R` with populated data and two distinct tab trees, and see them fail
- [x] 6c.2 Recreate symlinks without following them, continue after ENOENT clipboard entries, and refresh only the initiating view while starting at least one immediate git run
- [x] 6c.3 Run `make test FILE=tests/integration/file-tree/test_project_ops.lua CASE="Project tree"` and see them pass

## 7. Approved prompt renders
Scenarios: `file-tree: Project tree add prompt matches the approved render`, `file-tree: Project tree rename prompt matches the approved render`
- [x] 7.1 Write both cases in `tests/screen/file-tree/test_project_ops.lua` using the real Proposed F1 tree and mappings; assert text verbatim against `renders/g1_proposed.ansi` and `renders/g2_proposed.ansi`, plus real extmark groups and `H.expect_screen_colors` from the G1/G2 masks with no hand-made masks or self-blessed screenshots, and see them fail
- [x] 7.2 Adjust `picker/input.lua` and operation previews until the real frame, query, preview, hints and highlights match
- [x] 7.3 Run `make test FILE=tests/screen/file-tree/test_project_ops.lua` and compare the captures with both proposed ANSI artifacts

## 8. Architecture and final gates
Scenarios: `file-tree: Project tree operation keys come from the keymap file`, `file-tree: a creates a file`, `file-tree: r renames a file`, `diff: Diff view left window is read-only`, `diff: Diff view trim policy shows a staged checkbox`
- [x] 8.1 Run the new focused tests and existing neo-tree `tests/integration/file-tree/test_tree.lua`; fix any regression without weakening a scenario
- [x] 8.2 Update `docs/architecture.md` only for the new `file_tree/ops.lua`, `paths.lua`, `lsp_files.lua` and `picker/input.lua` module responsibilities allowed by rule 10
- [x] 8.3 Run `make test CAPS=find-action,actions,file-tree` (including `more_results` and neo-tree `test_tree.lua`), then run `make check`, and see both pass

## Agent decisions

- Delete confirmation uses singular `item` for one selected path, keeping the unsaved-buffer count grammatical.
- Create invalidates the root's cached scan before redrawing, so the submitted path is selected immediately without waiting for a watcher event.
- The input adapter wraps `frame.options`' renderer so live previews retain all shared-frame chrome without widening the frame API.
- The pre-audit PATH-worded trash scenarios remain verbatim as required; their tests also set `ops.state.trash_path` to the fake command, while production code checks only `/usr/bin/trash`.
- The existing exact-one refresh scenario remains verbatim; the auditor's at-least-one rule is covered by a separate scenario so neither contract is dropped.
- Path move preflight takes injected `lstat`, `stat` and directory-read functions and returns a reason plus failing path, keeping the helper pure and operation error wording outside it.
- Selection deduplication preserves the first-occurrence order of surviving top-level paths while dropping descendants regardless of selection order.
- Copy-name generation takes an explicit directory flag and conflict ordinal so dotted folder names and `_copy2` names are unambiguous.
- Task 4a installs only the `r` action and key needed by its real-entry-point tests; the other operation keys remain with stuck task 3b.
- Task 4b drives batch preflight through its public `ops.move(pairs)` entry point because Visual cut/paste mappings remain part of stuck task 3b.
- `ops.move` derives the root from the active project-tree view and returns success so later cut paste can retain its clipboard after a failed move.
- The case-only integration waits past the bounded LSP timeout so it observes the completed rename rather than an intermediate temporary sibling.
- Copy traversal preflights a parent-first source/destination list before creating anything, so recursive copies cannot partially write on an existing-path conflict.
- `watch.stop_all()` closes active handles but retains view registrations, so a manual refresh can safely rebuild the initiating view's watches.
- The Visual `d` regression waits for the confirmation picker, not `child.is_blocked()`: an unambiguous Visual `d` leaves MiniPick waiting in `getchar()`'s event loop, which Neovim never reports as blocking (normal `d` only blocked while the global `ds` mapping made it ambiguous).
- The prompt render legend maps the approved `#7daea3` cells to `FileTreeFolderIcon`, the group that draws folder icons in that colour; `FileTreeFolderName` is the default foreground.
- The input prompt keeps its hint-row padding in `MiniPickNormal` through a `PickerHintPadding` key of the frame's existing `highlight_overrides`, so other pickers' hint rows and reference screenshots stay unchanged.
- The input prompt's statusline overlay opens only when lualine is loaded and draws an empty row when lualine returns no statusline.
- Submitted create, rename and Copy names share one lexical validator so prompt-specific code cannot bypass root containment or segment rules.
- Move preflight checks the nearest existing destination ancestor's device, then creates missing destination parents before LSP traffic and filesystem moves.
