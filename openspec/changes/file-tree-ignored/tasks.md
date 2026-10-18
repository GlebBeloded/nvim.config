## 0. Extend the shipped git status request
Scenarios: `file-tree: Project tree reads git status without optional locks`
- [x] 0.1 Update the existing assertion in `tests/integration/file-tree/test_project_git.lua` for `--ignored=matching`; run `make test FILE=tests/integration/file-tree/test_project_git.lua CASE="Project tree reads git status without optional locks"` and see it fail
- [x] 0.2 Add `--ignored=matching` to the existing porcelain-v2 argv in `lua/gleb/file_tree/git.lua`, without adding another work-tree command
- [x] 0.3 Run `make test FILE=tests/integration/file-tree/test_project_git.lua CASE="Project tree reads git status without optional locks"`, then `make test CAPS=file-tree,picker`, and see them pass before starting ignored-entry code

## 1. Match settings and repository ignore rules
Scenarios: `file-tree: Settings ignore patterns hide entries`, `file-tree: Ignored nest children leave no chevron`, `file-tree: Ignore patterns apply outside a git repository`
- [x] 1.1 Extend `treeproj` in `tests/fixtures/build.sh` per design Decision 7, write the three scenarios in `tests/integration/file-tree/test_ignored.lua` using the real tree and settings file, and run `make test FILE=tests/integration/file-tree/test_ignored.lua` to see them fail
- [x] 1.2 Add the pure `lua/gleb/file_tree/ignore.lua`, validate and compile the `ignore` list once per settings generation in `settings.lua`, and filter entries before nesting without treating the tree root or its ancestors as ignored
- [x] 1.3 Run `make test FILE=tests/integration/file-tree/test_ignored.lua` and see the three scenarios pass

## 2a. Parse and map git ignored state
Scenarios: `file-tree: Ignored entries are hidden by default`, `file-tree: Tracked files matching gitignore stay listed`, `file-tree: Editing gitignore updates ignored entries`, `file-tree: Nested gitignore and negation are honoured`, `file-tree: Tree root inside an ignored folder stays visible`, `file-tree: Folder with only ignored content stays listed`, `file-tree: Ignored sets follow normalized roots across tabs`
- [ ] 2a.1 Write the seven scenarios in `tests/integration/file-tree/test_ignored.lua` with populated fixture copies, including repo and `web/` tabs under a symlink-normalized `/private/var` root, and run `make test FILE=tests/integration/file-tree/test_ignored.lua` to see them fail
- [ ] 2a.2 Make `model.parse_status` return a separate ignored set for `!` records, store it in `FileTreeGitRoot` under the existing generation/in-flight/dirty lifecycle, map it through the shipped prefix stripping and normalized roots, and bump its generation only when the set changes
- [ ] 2a.3 Change every `model.rows` call to pass `{ status, ignored, show_ignored, matcher }`, preserve non-ignored empty folders, and run `make test FILE=tests/integration/file-tree/test_ignored.lua` to see the seven scenarios pass

## 2b. Gate first paint on initial ignored state
Scenarios: `file-tree: First paint waits for ignored status`
- [ ] 2b.1 Write the scenario in `tests/integration/file-tree/test_ignored.lua` against the real `file_tree.toggle` entry point and run `make test FILE=tests/integration/file-tree/test_ignored.lua CASE="First paint waits for ignored status"` to see it fail
- [ ] 2b.2 Once watch has `toplevel`, skip debounce for only the first request and delay only the first git-backed draw until the result or 300 ms; never wait on later refreshes or outside git
- [ ] 2b.3 Run `make test FILE=tests/integration/file-tree/test_ignored.lua CASE="First paint waits for ignored status"` and see it pass

## 2c. Block every hidden-path reveal
Scenarios: `file-tree: File under hidden node_modules is not revealed`, `file-tree: Created or renamed ignored target is not selected`
- [ ] 2c.1 Write the two scenarios in `tests/integration/file-tree/test_ignored.lua`, driving `:edit`, the real create action and the real rename action, and run `make test FILE=tests/integration/file-tree/test_ignored.lua` to see them fail
- [ ] 2c.2 Add one `is_hidden(view, path)` gate before `expand_to` in follow, reveal, `select_created` and `refresh_moved`, so hidden targets change no expansion, nest, persisted state or cursor
- [ ] 2c.3 Run `make test FILE=tests/integration/file-tree/test_ignored.lua` and see the two scenarios pass

## 2d. Keep direct hidden follow stable
Scenarios: `file-tree: Hidden ignored file is not revealed`
- [ ] 2d.1 Write the scenario in `tests/integration/file-tree/test_ignored.lua`, drive `:edit .env`, and run `make test FILE=tests/integration/file-tree/test_ignored.lua CASE="Hidden ignored file is not revealed"` to see it fail
- [ ] 2d.2 Apply the shared hidden-path gate to the follow callback without moving the tree cursor
- [ ] 2d.3 Run `make test FILE=tests/integration/file-tree/test_ignored.lua CASE="Hidden ignored file is not revealed"` and see it pass

## 3. Add Show Ignored action and state
Scenarios: `file-tree: I toggles ignored entries`, `file-tree: Show Ignored is a Find Action toggle`, `file-tree: Show Ignored persists`, `file-tree: Saved Show Ignored state is restored`, `file-tree: Hiding the selected ignored row moves upward`
- [ ] 3.1 Write the five scenarios in `tests/integration/file-tree/test_ignored.lua`, driving `I`, `<M-A>` and the real picker with populated tree data, and run `make test FILE=tests/integration/file-tree/test_ignored.lua` to see them fail
- [ ] 3.2 Add `lua/gleb/file_tree/state.lua`, the `file_tree.show_ignored` toggle with a real `run`, and `"file_tree.show_ignored": ["I"]` in `settings/keymap.json`; redraw every view and select the nearest listed row above when the current row disappears
- [ ] 3.3 Run `make test FILE=tests/integration/file-tree/test_ignored.lua`, then `make quick`, and see them pass

## 4a. Draw ignored rows
Scenarios: `file-tree: Ignored rows are grey italic`
- [ ] 4a.1 Write the scenario in `tests/integration/file-tree/test_ignored.lua` with real extmark groups and `H.expect_hl_colors`, and run `make test FILE=tests/integration/file-tree/test_ignored.lua CASE="Ignored rows are grey italic"` to see it fail
- [ ] 4a.2 Define `FileTreeIgnored` as palette grey0 italic, draw ignored icons and names with it, and exclude ignored rows from git colour and folder tint
- [ ] 4a.3 Run `make test FILE=tests/integration/file-tree/test_ignored.lua CASE="Ignored rows are grey italic"` and see it pass

## 4b. Prevent descent through ignored folders
Scenarios: `file-tree: Unfold all leaves ignored folders collapsed`, `file-tree: Expanded ignored folder lists ignored children`, `file-tree: Ignored folders do not compact or consume unfold budget`
- [ ] 4b.1 Write the three scenarios in `tests/integration/file-tree/test_ignored.lua` using `zR` and `za`, and run `make test FILE=tests/integration/file-tree/test_ignored.lua` to see them fail
- [ ] 4b.2 Pass ignored state down from the parent, scan and watch an ignored folder only on explicit expansion, keep unfold-all out of ignored folders, filter before compaction, and count only listed rows toward caps
- [ ] 4b.3 Run `make test FILE=tests/integration/file-tree/test_ignored.lua` and see the three scenarios pass

## 5. Pin the approved screen
Scenarios: `file-tree: Show Ignored matches the approved render`
- [ ] 5.1 Write the 100x30 case in `tests/screen/file-tree/test_ignored.lua`, pass `H.GIT_ENV` to the child, compare text verbatim with a byte-identical `tests/screen/file-tree/ign_proposed.ansi`, assert real extmark groups without a mask or self-blessed screenshot, and run `make test FILE=tests/screen/file-tree/test_ignored.lua CASE="Show Ignored matches the approved render"` to see it fail
- [ ] 5.2 Make the rendered text and groups match `Proposed — after Show Ignored`, then run `make test FILE=tests/screen/file-tree/test_ignored.lua CASE="Show Ignored matches the approved render"` and see it pass
- [ ] 5.3 Run `make check`

## Agent decisions

- The two git-derived scenarios move from task 1 to task 2a because Decision 2 assigns their required porcelain ignored-set parsing, storage and root mapping there.
- The compiled settings matcher is an optional model argument until task 2a replaces the row inputs with the designed options table, keeping filtering independent of nesting configuration.
