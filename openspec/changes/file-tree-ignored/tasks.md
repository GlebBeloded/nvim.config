## 1. Ignored set and globs

Scenarios: `file-tree: Settings ignore patterns hide entries`, `file-tree: Ignored nest children leave no chevron`, `file-tree: Ignore patterns apply outside a git repository`

- [ ] 1.1 Extend the `treeproj` fixture in `tests/fixtures/build.sh` per design Decision 7, write the three scenarios in `tests/integration/file-tree/test_ignored.lua` (settings path set to a temporary copy, `vim.system` and `vim.notify` recorded), and see them fail
- [ ] 1.2 Add `lua/gleb/file_tree/ignore.lua` (pure, rule 1.3) per Decision 1, validate `ignore` in `settings.lua`, add `"ignore": []` handling, and filter listings in `model.lua` before nesting
- [ ] 1.3 Run the file and see it pass

## 2. Git ignored query

Scenarios: `file-tree: Ignored entries are hidden by default`, `file-tree: Tracked files matching gitignore stay listed`, `file-tree: Editing gitignore updates ignored entries`, `file-tree: Hidden ignored file is not revealed`

- [ ] 2.1 Write the four scenarios in `tests/integration/file-tree/test_ignored.lua` (fresh fixture copy each), and see them fail
- [ ] 2.2 Add the async `git ls-files --others --ignored --exclude-standard --directory -z` query to `git.lua` on the status query's triggers, with generation checks and the first-paint wait (Decisions 2 and 4); drop `.git` in the listing; make follow and reveal skip hidden ignored files
- [ ] 2.3 Run the file and see it pass

## 3. Show Ignored action and state

Scenarios: `file-tree: I toggles ignored entries`, `file-tree: Show Ignored is a Find Action toggle`, `file-tree: Show Ignored persists`, `file-tree: Saved Show Ignored state is restored`

- [ ] 3.1 Write the four scenarios in `tests/integration/file-tree/test_ignored.lua`, and see them fail
- [ ] 3.2 Add `lua/gleb/file_tree/state.lua`, the `file_tree.show_ignored` toggle action with a real `run`, and `"file_tree.show_ignored": ["I"]` in `settings/keymap.json` (Decision 5)
- [ ] 3.3 Run the file and `make quick` (action catalog and Find Action layers), and see them pass

## 4. Look and no descent

Scenarios: `file-tree: Ignored rows are grey italic`, `file-tree: Unfold all leaves ignored folders collapsed`, `file-tree: Expanded ignored folder lists ignored children`

- [ ] 4.1 Write the three scenarios in `tests/integration/file-tree/test_ignored.lua` (`H.expect_hl_colors` for `FileTreeIgnored` with the palette's grey0, italic), and see them fail
- [ ] 4.2 Define `FileTreeIgnored` from the palette with the other `FileTree*` groups, draw ignored icons and names with it, skip git colours and folder tint for ignored rows, make `file_tree.unfold_all` skip ignored folders, and list an ignored folder's content only on expand (Decision 6)
- [ ] 4.3 Run the file and see it pass

## 5. Screen

Scenarios: `file-tree: Show Ignored matches the approved render`

- [ ] 5.1 Add the case to `tests/screen/file-tree/test_ignored.lua` at 100x30 with the reference screenshot from "Proposed — after Show Ignored" (real glyphs, attribute blocks per the mask groups), plus `H.expect_screen_colors` with the render's mask and legend for the tree columns, and see it fail
- [ ] 5.2 Make it pass, then compare `make render` of the case with `renders/ign_proposed.ansi` and `make colorize FILE=openspec/changes/file-tree-ignored/design.md`
- [ ] 5.3 Run `make check`
