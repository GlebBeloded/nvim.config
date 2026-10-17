## 1. Fixture and model

Scenarios: `git: Changes panel lists the dirty fixture`, `git: Changes panel compacts single-child directories`, `git: Changes panel hides an empty Unversioned Files root`, `git: Changes panel checkboxes follow the index`, `git: Changes panel shows line stats`, `git: Changes panel nests tests under their file`, `git: Changes panel keeps a lone test file flat`

- [ ] 1.1 Add the `billing` fixture to `tests/fixtures/build.sh` exactly as design.md (Fixture), its header line, and the `billing` case in the fixture-name `case`; build it and check `git diff --numstat HEAD` gives the design's numbers and `HEAD` is `4ccefde`
- [ ] 1.2 Write the scenarios as model cases in `tests/unit/git/test_changes_model.lua` (porcelain v2 `-z` and numstat `-z` inputs captured from `dirty`, `billing` and the temp repos of the scenarios, incl. a rename, an unmerged and a binary record) and see them fail
- [ ] 1.3 Add `lua/gleb/git/changes/model.lua` (design Decisions 2, 3, 5 and the nesting call of Decision 1), pure, LuaCATS-typed
- [ ] 1.4 Run `make test FILE=tests/unit/git/test_changes_model.lua` and see it pass

## 2. Render and highlights

Scenarios: `git: Changes panel cuts a long name before the stats`, `git: Changes panel colours names by status`, `git: Changes panel highlight colours`

- [ ] 2.1 Write the scenarios in `tests/unit/git/test_changes_render.lua` (columns of design Decision 5, `…` cut, spans) and `tests/integration/git/test_changes.lua` (extmark groups, `H.expect_hl_colors`) and see them fail
- [ ] 2.2 Add `lua/gleb/git/changes/render.lua` and `highlights.lua` (`Changes*` from the palette helpers, `ColorScheme` autocmd in `gleb_changes_highlights`)
- [ ] 2.3 Run both files and see them pass

## 3. Panel window, git runner and keys

Scenarios: `git: Changes panel opens on the left at width 35`, `git: Changes panel cursor starts on the first file`, `git: Changes panel toggle closes the focused panel`, `git: Changes panel toggle focuses an open panel`, `git: Changes panel outside a repository`, `git: Changes panel mappings come from the shortcut file`, `git: Changes panel leaves gr global`, `git: Changes panel entry points are actions`, `git: Changes panel za folds a nest`, `git: Changes panel Enter folds a directory`, `git: Changes panel refreshes after a write`, `git: Changes panel replaces the project tree`

- [ ] 3.1 Write the scenarios in `tests/integration/git/test_changes.lua` and see them fail
- [ ] 3.2 Add `git.lua` (argument-list `vim.system` calls with `cwd = root`, refresh generation), `view.lua` (window, buffer, folds, refresh autocmds in `gleb_changes`), `init.lua` (`open`, `close`, `toggle`, `review`, `M.state`, `M.reset()`), `actions.lua`; append the actions in `lua/gleb/git/actions.lua`, require `gleb.git.changes` from `lua/gleb/git/init.lua`, add the eight `changes.*` entries to `settings/keymap.json` (design Decision 13)
- [ ] 3.3 Close a `gleb-file-tree` window when the panel opens (design Decision 12)
- [ ] 3.4 Run `make test FILE=tests/integration/git/test_changes.lua` and see it pass

## 4. Staging

Scenarios: `git: Changes panel Space stages an unstaged file`, `git: Changes panel Space unstages a staged file`, `git: Changes panel Space stages a partially staged file`, `git: Changes panel Space stages an untracked file`, `git: Changes panel Space stages a file whose name is a suffix of a staged file`, `git: Changes panel stages when cwd is outside the repository`, `git: Changes panel unstages when cwd is outside the repository`, `git: Changes panel stages from a subdirectory cwd`, `git: Changes panel unstages from a subdirectory cwd`, `git: Changes panel reports a staging failure`, `git: Changes panel Space on the Changes root stages every tracked file`, `git: Changes panel A stages everything`

- [ ] 4.1 Write the scenarios in `tests/integration/git/test_changes_stage.lua` (port the setups of `tests/integration/file-tree/test_stage.lua`) and see them fail
- [ ] 4.2 Implement `changes.toggle_stage` and `changes.stage_all` (design Decision 4)
- [ ] 4.3 Run the file and see it pass

## 5. Diff view link

Scenarios: `git: Changes panel j shows the next file in the diff view`, `git: Changes panel debounces rapid moves`, `git: Changes panel shows an untracked file as added`, `git: Changes panel shows a deleted file`, `git: Changes panel keeps the diff on a directory row`, `git: Changes panel review shows the current file's diff`, `git: Changes panel review without a changed current file`, `git: Changes panel ]f steps through every changed file`, `git: Changes panel Enter opens the file`, `git: Changes panel q closes the panel and the diff view`, `git: Project tree replaces the changes panel`

- [ ] 5.1 Write the scenarios in `tests/integration/git/test_changes_diff.lua` (wrap the diff view's show function to record shown paths for the debounce case) and see them fail
- [ ] 5.2 Link `view.lua` to the `diff-view` API (design Decisions 6–8): debounce timer, generation check, editor window and buffer restore, `changes.open`, `changes.close`, `changes.review`, the next-file hook; make `file_tree.toggle`/`file_tree.reveal` call `require("gleb.git.changes").close()` first
- [ ] 5.3 Run the file and see it pass

## 6. Revert, commit, push

Scenarios: `git: Changes panel X reverts a file after confirmation`, `git: Changes panel X keeps a file when revert is declined`, `git: Changes panel X unstages a new file and keeps it`, `git: Changes panel X ignores an unversioned file`, `git: Changes panel gc commits confirmed message`, `git: Changes panel gc reports commit failure`, `git: Changes panel P pushes successfully`, `git: Changes panel P reports push failure`

- [ ] 6.1 Write the scenarios in `tests/integration/git/test_changes_actions.lua` (port the commit and push setups of `tests/integration/file-tree/test_tree.lua`: popup stub, failing `pre-commit` hook, bare remote) and see them fail
- [ ] 6.2 Implement `changes.revert` (design Decision 9), `changes.commit` and `changes.push` (Decision 10)
- [ ] 6.3 Run the file and see it pass

## 7. Screens

Scenarios: `git: Changes panel matches the approved render`, `git: Changes panel with the diff view matches the approved render`

- [ ] 7.1 Write both cases in `tests/screen/git/test_changes_screen.lua` (100x30, `billing` fixture; text screenshot of the scenario's rows and columns plus `H.expect_screen_colors` with the masks and legends of design.md "Proposed A" and "Proposed B") and see them fail
- [ ] 7.2 Adjust render and highlights until both pass; compare `make render` of the state with `make colorize FILE=openspec/changes/git-changes-tree/design.md CASE=neo-tree`
- [ ] 7.3 Commit the new reference screenshots after review

## 8. Gate

- [ ] 8.1 `make trace` lists every scenario of this change as tested, with no orphans
- [ ] 8.2 `make check` is green; `openspec validate git-changes-tree --strict` passes
