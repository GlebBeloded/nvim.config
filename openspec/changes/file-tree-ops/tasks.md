## 1. Picker input prompt

Scenarios: `picker: Input prompt submits its query`, `picker: Input prompt starts with its default and previews it`, `picker: Input prompt cancels with Esc`, `picker: Input prompt ignores a blank query`

- [ ] 1.1 Write the scenarios in `tests/integration/picker/test_input.lua`, and see them fail.
- [ ] 1.2 Add `lua/gleb/picker/input.lua` on the shared frame (design Decision 7), with LuaCATS for its options.
- [ ] 1.3 Run the file and `make test CAPS=picker`, and see them pass.

## 2. Pure helpers

Scenarios: none directly. These unit cases back the scenarios in groups 3–6.

- [ ] 2.1 Write `tests/unit/file-tree/test_paths.lua`:
  - target folder for root, folder, compact and file rows;
  - `copy_name` for `invoice.go`, `money` and `.env`;
  - `is_inside`;
  - `dedupe` of nested selections;
  - `filter_matches` for `**/*.go`, `**/*.{ts,tsx}`, `ignoreCase` and `matches = "folder"`.

  See it fail.
- [ ] 2.2 Add `lua/gleb/file_tree/paths.lua` (pure, rule 1.3), and see it pass.

## 3. Create

Scenarios: `file-tree: Project tree a creates a file in the folder under the cursor`, `file-tree: Project tree a on a file creates next to it`, `file-tree: Project tree a with a trailing slash creates a folder`, `file-tree: Project tree a creates missing parent folders`, `file-tree: Project tree a reports an existing name`

- [ ] 3.1 Write the scenarios in `tests/integration/file-tree/test_project_ops.lua`, each on its own `treeproj` copy, and see them fail.
- [ ] 3.2 Add `file_tree.add` to `ops.lua` and `actions.lua`, with its key in `settings/keymap.json` (Decisions 2, 3, 10). Teach `view.lua` to select a given path.
- [ ] 3.3 Run the file and see it pass.

## 4. Rename and LSP file operations

Scenarios: `file-tree: Project tree r renames a file and its buffer`, `file-tree: Project tree r renames a folder and the buffers inside`, `file-tree: Project tree rename asks language servers to update references`, `file-tree: Project tree rename skips servers whose filters do not match`, `file-tree: Project tree rename waits for servers at most one second`, `file-tree: Project tree r reports an existing name`

- [ ] 4.1 Write the scenarios in `tests/integration/file-tree/test_project_ops.lua` and `test_project_lsp_rename.lua` (an in-process fake server through `vim.lsp.start` with a `cmd` function that records requests), and see them fail.
- [ ] 4.2 Add `lsp_files.lua` and `file_tree.rename` (Decisions 4, 5).
- [ ] 4.3 Run both files and see them pass.

## 5. Delete

Scenarios: `file-tree: Project tree d moves a file to the Trash after confirmation`, `file-tree: Project tree d keeps the file when cancelled`, `file-tree: Project tree Visual d deletes every selected row`, `file-tree: Project tree d deletes without a trash command`, `file-tree: Project tree d closes buffers of deleted files`, `file-tree: Project tree d reports a failed delete`

- [ ] 5.1 Write the scenarios in `tests/integration/file-tree/test_project_ops.lua`. A fake `trash` script in a temp dir is put first on the child's `PATH`; it records its arguments to a file, then removes or fails. The real user Trash is never touched. Choices are made through the picker by typing the choice and `<CR>`. See them fail.
- [ ] 5.2 Add `file_tree.delete` in normal and Visual mode (Decision 6).
- [ ] 5.3 Run the file and see it pass.

## 6. Copy, cut, paste and refresh

Scenarios: `file-tree: Project tree c and p copy a file into another folder`, `file-tree: Project tree pasting a copy over an existing name asks for a new name`, `file-tree: Project tree c and p copy a folder recursively`, `file-tree: Project tree x and p move a file like a rename`, `file-tree: Project tree refuses to paste a folder into itself`, `file-tree: Project tree Visual c copies every selected row`, `file-tree: Project tree R picks up changes at once`, `file-tree: Project tree operation keys come from the keymap file`

- [ ] 6.1 Write the scenarios in `tests/integration/file-tree/test_project_ops.lua`, and see them fail.
- [ ] 6.2 Add `file_tree.copy`, `cut`, `paste` and `refresh` (Decisions 8, 9, 10).
- [ ] 6.3 Run the file and see it pass.

## 7. Approved prompt renders

Scenarios: `file-tree: Project tree add prompt matches the approved render`, `file-tree: Project tree rename prompt matches the approved render`

- [ ] 7.1 Write both cases in `tests/screen/file-tree/test_project_ops.lua`. They reuse the "Proposed F1" setup of `tests/screen/file-tree/test_project_tree.lua` (a shared local helper), then press `a` + `tax_rate.go` or `r`. They assert the screenshot and `H.expect_screen_colors` for the prompt rows with the masks of "Proposed G1" and "Proposed G2". See them fail.
- [ ] 7.2 Adjust `picker/input.lua` until they pass. Compare `make render` (a temporary case) with `renders/g1_proposed.ansi` and `renders/g2_proposed.ansi`.
- [ ] 7.3 Run `make check`.
