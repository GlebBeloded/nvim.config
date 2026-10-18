## 1. Shared porcelain parser
Scenarios: `file-tree: Shared parser preserves rename and copy origins`, `file-tree: Shared parser classifies added and unmerged records`, `file-tree: Shared parser keeps ignored records separate`
- [x] 1.1 Write the scenarios in `tests/unit/file-tree/test_model.lua`, drive `parse_status_records` and `parse_status` with real porcelain-v2 NUL records, and see them fail
- [x] 1.2 Extract `gleb.file_tree.model.parse_status_records`; keep `parse_status` and ignored-set compatibility wrappers and make the Changes model consume only the records
- [x] 1.3 Run `make test FILE=tests/unit/file-tree/test_model.lua CASE="Shared parser"` and see it pass

## 2a. Status rows and fixture
Scenarios: `git: Changes panel lists the dirty fixture`, `git: Changes panel compacts single-child directories`, `git: Changes panel hides an empty Unversioned Files root`, `git: Changes panel keeps one path in both roots`, `git: Changes panel lists directory and submodule records`
- [x] 2a.1 Add the scenarios to `tests/unit/git/test_changes_model.lua`, using populated porcelain-v2 records and explicitly loaded default nesting rules, and see them fail
- [x] 2a.2 Add the `billing` fixture to `tests/fixtures/build.sh` exactly as design.md (Fixture), including its header and fixture-name case; build it and verify its numstat and `4ccefde` HEAD, then implement single-pass grouping in `lua/gleb/git/changes/model.lua`
- [x] 2a.3 Run `make test FILE=tests/unit/git/test_changes_model.lua CASE="Changes panel"` and see it pass

## 2b. Status command and row cap
Scenarios: `git: Changes panel status avoids optional locks`, `git: Changes panel caps rows`
- [x] 2b.1 Write the scenarios in `tests/unit/git/test_changes_model.lua` and `tests/integration/git/test_changes.lua`, driving a real panel refresh, and see them fail
- [x] 2b.2 Add the no-optional-locks status command and project-tree row cap to the Changes model and git runner
- [x] 2b.3 Run `make test FILE=tests/integration/git/test_changes.lua CASE="Changes panel status"` and see it pass

## 2c. Render and status highlights
Scenarios: `git: Changes panel colours names by status`, `git: Changes panel highlight colours`, `git: Changes panel treats copies as renamed`
- [x] 2c.1 Write the scenarios in `tests/unit/git/test_changes_render.lua` and `tests/integration/git/test_changes.lua`, including real extmark groups and `H.expect_hl_colors`, and see them fail
- [x] 2c.2 Add `lua/gleb/git/changes/render.lua` and `highlights.lua`, using palette helpers and a `gleb_changes_highlights` ColorScheme autocmd
- [x] 2c.3 Run `make test FILE=tests/unit/git/test_changes_render.lua CASE="Changes panel"` and `make test FILE=tests/integration/git/test_changes.lua CASE="Changes panel highlight colours"` and see them pass

## 2d. Staging checkboxes
Scenarios: `git: Changes panel checkboxes follow the index`
- [x] 2d.1 Write the scenario in `tests/unit/git/test_changes_model.lua` with populated staged, unstaged and mixed records and see it fail
- [x] 2d.2 Derive file and root checkbox states from the porcelain index and worktree columns
- [x] 2d.3 Run `make test FILE=tests/unit/git/test_changes_model.lua CASE="Changes panel checkboxes follow the index"` and see it pass

## 2e. Line statistics
Scenarios: `git: Changes panel shows line stats`, `git: Changes panel cuts a long name before the stats`, `git: Changes panel omits unmatched numstat`, `git: Changes panel on unborn HEAD has no stats`
- [x] 2e.1 Write the scenarios in `tests/unit/git/test_changes_model.lua` and `tests/unit/git/test_changes_render.lua` with populated numstat data and see them fail
- [x] 2e.2 Parse and join numstat by status record, omit missing and binary stats, skip unborn HEAD, and implement the approved columns and `…` cut
- [x] 2e.3 Run `make test FILE=tests/unit/git/test_changes_render.lua CASE="Changes panel"` and see it pass

## 2f. File nesting
Scenarios: `git: Changes panel nests tests under their file`, `git: Changes panel keeps a lone test file flat`
- [x] 2f.1 Write the scenarios in `tests/unit/git/test_changes_model.lua`, explicitly loading the default nesting rules, and see them fail
- [x] 2f.2 Apply the file-tree nesting engine while building Changes rows
- [x] 2f.3 Run `make test FILE=tests/unit/git/test_changes_model.lua CASE="Changes panel nests"` and see it pass

## 3a. Window, toggle and repository detection
Scenarios: `git: Changes panel opens on the left at width 35`, `git: Changes panel cursor starts on the first file`, `git: Changes panel toggle closes the focused panel`, `git: Changes panel toggle focuses an open panel`, `git: Changes panel outside a repository`
- [x] 3a.1 Write the scenarios in `tests/integration/git/test_changes.lua`, driving `changes.toggle` against populated fixtures and a real outside-repository cwd, and see them fail
- [x] 3a.2 Add `git.lua`, `view.lua`, `init.lua`, `actions.lua`; register the entry points from `lua/gleb/git/actions.lua` and load the module from `lua/gleb/git/init.lua`
- [x] 3a.3 Run `make test FILE=tests/integration/git/test_changes.lua CASE="Changes panel"` and see it pass

## 3b. Keys and action catalog
Scenarios: `git: Changes panel mappings come from the shortcut file`, `git: Changes panel leaves gr global`, `git: Changes panel entry points are actions`
- [x] 3b.1 Write the scenarios in `tests/integration/git/test_changes.lua`, opening a real `gleb-changes` buffer and reading the real action catalog, and see them fail
- [x] 3b.2 Add the eight view-scoped `changes.*` entries to `settings/keymap.json` with no `plugin`, preserve global `gr`, and add `changes.toggle` and `changes.review` to Find Action's approved list
- [x] 3b.3 Run `make test FILE=tests/integration/git/test_changes.lua CASE="Changes panel"` and see it pass

## 3c. Folds and refresh
Scenarios: `git: Changes panel za folds a nest`, `git: Changes panel Enter folds a directory`, `git: Changes panel refreshes after a write`, `git: Changes panel refreshes after hunk staging`, `git: Changes panels isolate two tabs`
- [x] 3c.1 Write the scenarios in `tests/integration/git/test_changes.lua`, driving real panel mappings, writes, diff-view hunk staging and two tabs, and see them fail
- [x] 3c.2 Implement fold state, scoped refresh autocmds, per-tab timers and generations, the shared git-dir event, and `diff.view.refresh_index(view)` after panel git commands
- [x] 3c.3 Run `make test FILE=tests/integration/git/test_changes.lua CASE="Changes panel"` and see it pass

## 3d. Left-slot swap
Scenarios: `git: Changes panel replaces the project tree`
- [x] 3d.1 Write the scenario in `tests/integration/git/test_changes.lua`, driving the real `changes.toggle` action with the project tree open, and see it fail
- [x] 3d.2 Close the project tree when the Changes panel opens
- [x] 3d.3 Run `make test FILE=tests/integration/git/test_changes.lua CASE="replaces"` and see it pass

## 3e. Window isolation
Scenarios: `git: Changes panel normalizes a private-var root`, `git: Changes panel revalidates the editor window`, `git: Changes panel closes when orphaned`
- [x] 3e.1 Write the scenarios in `tests/integration/git/test_changes.lua`, using the symlinked root and real window lifecycle, and see them fail
- [x] 3e.2 Export the project-tree eligible-editor helper, exclude `gleb-changes`, normalize identities, revalidate before show, and mirror QuitPre and orphan-close
- [x] 3e.3 Run `make test FILE=tests/integration/git/test_changes.lua CASE="Changes panel"` and see it pass

## 4a. File staging
Scenarios: `git: Changes panel Space stages an unstaged file`, `git: Changes panel Space unstages a staged file`, `git: Changes panel Space stages a partially staged file`, `git: Changes panel Space stages an untracked file`, `git: Changes panel Space stages a file whose name is a suffix of a staged file`
- [x] 4a.1 Write the scenarios in `tests/integration/git/test_changes_stage.lua`, porting populated setups from `tests/integration/file-tree/test_stage.lua`, and see them fail
- [x] 4a.2 Implement `changes.toggle_stage` from one fresh porcelain-v2 status decision with literal pathspecs
- [x] 4a.3 Run `make test FILE=tests/integration/git/test_changes_stage.lua CASE="Changes panel Space"` and see it pass

## 4b. Repository-relative staging
Scenarios: `git: Changes panel stages when cwd is outside the repository`, `git: Changes panel unstages when cwd is outside the repository`, `git: Changes panel stages from a subdirectory cwd`, `git: Changes panel unstages from a subdirectory cwd`, `git: Changes panel reports a staging failure`
- [x] 4b.1 Write the scenarios in `tests/integration/git/test_changes_stage.lua`, driving `<Space>` in real panels with populated repositories, and see them fail
- [x] 4b.2 Run every status and mutation in the panel root and surface staging failures
- [x] 4b.3 Run `make test FILE=tests/integration/git/test_changes_stage.lua CASE="Changes panel"` and see it pass

## 4c. Batch and conflict staging
Scenarios: `git: Changes panel Space on the Changes root stages every tracked file`, `git: Changes panel stages literal metacharacter paths`, `git: Changes panel refuses to stage an unmerged file`, `git: Changes panel unstages a rename literally`
- [x] 4c.1 Write the scenarios in `tests/integration/git/test_changes_stage.lua`, including `[ab].txt`, an unmerged index and a real rename, and see them fail
- [x] 4c.2 Batch selected paths, switch above 100 paths to NUL pathspec input, refuse unmerged files, and reset both rename paths literally
- [x] 4c.3 Run `make test FILE=tests/integration/git/test_changes_stage.lua CASE="Changes panel"` and see it pass

## 4d. Stage all
Scenarios: `git: Changes panel A stages everything`
- [x] 4d.1 Write the scenario in `tests/integration/git/test_changes_stage.lua`, press `A` in the populated dirty fixture, and see it fail
- [x] 4d.2 Implement `changes.stage_all` with `git --literal-pathspecs add -A`
- [x] 4d.3 Run `make test FILE=tests/integration/git/test_changes_stage.lua CASE="Changes panel A stages everything"` and see it pass

## 5a. Show, debounce and exceptional content
Scenarios: `git: Changes panel j shows the next file in the diff view`, `git: Changes panel debounces rapid moves`, `git: Changes panel shows an untracked file as added`, `git: Changes panel shows a deleted file`, `git: Changes panel closes a contentless diff`
- [x] 5a.1 Write the scenarios in `tests/integration/git/test_changes_diff.lua`, driving panel cursor movement and the real picker with populated files while wrapping `diff.view.show` only to observe calls, and see them fail
- [x] 5a.2 Build full diff specs asynchronously with the 50 ms debounce, panel-owned view handle, empty added side, read-only deleted side, and nil-show close notification
- [x] 5a.3 Run `make test FILE=tests/integration/git/test_changes_diff.lua CASE="Changes panel"` and see it pass

## 5b. Review and next-file navigation
Scenarios: `git: Changes panel review shows the current file's diff`, `git: Changes panel review without a changed current file`, `git: Changes panel ]f steps through every changed file`, `git: Changes panel ]f keeps diff focus`
- [x] 5b.1 Write the scenarios in `tests/integration/git/test_changes_diff.lua`, driving `changes.review` and `]f` in the real diff view, and see them fail
- [x] 5b.2 Implement immediate review and `on_next_file`, refocusing the replacement view's `right_win` when navigation starts in a diff window
- [x] 5b.3 Run `make test FILE=tests/integration/git/test_changes_diff.lua CASE="Changes panel"` and see it pass

## 5c. Enter, close and project-tree swap
Scenarios: `git: Changes panel Enter opens the file`, `git: Changes panel q closes the panel and the diff view`, `git: Project tree replaces the changes panel`
- [x] 5c.1 Write the scenarios in `tests/integration/git/test_changes_diff.lua`, driving `<CR>`, `q` and `file_tree.toggle` in populated views, and see them fail
- [x] 5c.2 Implement open and close around the panel-owned view, leaving editor restoration to `windows.restore`, and make project-tree opening close Changes first
- [x] 5c.3 Run `make test FILE=tests/integration/git/test_changes_diff.lua CASE="Changes panel"` and see it pass

## 5d. Diff generations
Scenarios: `git: Changes panel keeps the diff on a directory row`, `git: Changes panel drops a stale diff result`, `git: Changes panel skips an unchanged selection`
- [x] 5d.1 Write the scenarios in `tests/integration/git/test_changes_diff.lua`, using real panel rows and controlled asynchronous completion, and see them fail
- [x] 5d.2 Add root and selection generation checks and same-path suppression
- [x] 5d.3 Run `make test FILE=tests/integration/git/test_changes_diff.lua CASE="Changes panel"` and see it pass

## 5e. Non-actionable diffs
Scenarios: `git: Changes panel binary row uses a read-only diff`, `git: Changes panel unmerged row uses a read-only diff`, `git: Changes panel submodule row has no diff`
- [x] 5e.1 Write the scenarios in `tests/integration/git/test_changes_diff.lua` with populated binary, conflict and submodule records and see them fail
- [x] 5e.2 Mark exceptional specs non-actionable, use read-only buffers without `bufadd`, and notify without loading submodule content
- [x] 5e.3 Run `make test FILE=tests/integration/git/test_changes_diff.lua CASE="Changes panel"` and see it pass

## 5f. Owned-view cleanup
Scenarios: `git: Changes panel close preserves another diff view`, `git: Changes panel unloads its clean file buffer`
- [x] 5f.1 Write the scenarios in `tests/integration/git/test_changes_diff.lua` with two real view handles and a panel-loaded buffer and see them fail
- [x] 5f.2 Close only the panel-owned view and unload only clean buffers loaded by the panel
- [x] 5f.3 Run `make test FILE=tests/integration/git/test_changes_diff.lua CASE="Changes panel"` and see it pass

## 6a. Revert tracked and local files
Scenarios: `git: Changes panel X reverts a file after confirmation`, `git: Changes panel X keeps a file when revert is declined`, `git: Changes panel X unstages a new file and keeps it`, `git: Changes panel X ignores an unversioned file`, `git: Changes panel X reverts a rename`
- [x] 6a.1 Write the scenarios in `tests/integration/git/test_changes_actions.lua`, driving `X` in populated repositories and the real confirmation callback, and see them fail
- [x] 6a.2 Implement literal-pathspec revert, decline, added-file, unversioned and rename paths with the existing prompt and failure text
- [x] 6a.3 Run `make test FILE=tests/integration/git/test_changes_actions.lua CASE="Changes panel X"` and see it pass

## 6b. Revert on unborn HEAD
Scenarios: `git: Changes panel X on unborn HEAD keeps the file`
- [x] 6b.1 Write the scenario in `tests/integration/git/test_changes_actions.lua` with a staged file in a repository without commits and see it fail
- [x] 6b.2 Fall back to literal-pathspec `rm --cached` when HEAD is unborn
- [x] 6b.3 Run `make test FILE=tests/integration/git/test_changes_actions.lua CASE="Changes panel X on unborn HEAD keeps the file"` and see it pass

## 6c. Commit
Scenarios: `git: Changes panel gc commits confirmed message`, `git: Changes panel gc reports commit failure`
- [x] 6c.1 Write the scenarios in `tests/integration/git/test_changes_actions.lua`, porting the real popup stub and failing pre-commit hook setup from `tests/integration/file-tree/test_tree.lua`, and see them fail
- [x] 6c.2 Call `gleb.git.ai_commit.show_commit_input(on_commit, { root = root })`, commit with literal pathspecs, refresh and preserve the specified notifications
- [x] 6c.3 Run `make test FILE=tests/integration/git/test_changes_actions.lua CASE="Changes panel gc"` and see it pass

## 6d. Push
Scenarios: `git: Changes panel P pushes successfully`, `git: Changes panel P reports push failure`
- [x] 6d.1 Write the scenarios in `tests/integration/git/test_changes_actions.lua`, porting the populated bare-remote setup from `tests/integration/file-tree/test_tree.lua`, and see them fail
- [x] 6d.2 Run push asynchronously in the panel root with the existing notifications
- [x] 6d.3 Run `make test FILE=tests/integration/git/test_changes_actions.lua CASE="Changes panel P"` and see it pass

## 7. Approved screens
Scenarios: `git: Changes panel matches the approved render`, `git: Changes panel with the diff view matches the approved render`
- [x] 7.1 Write both `100x30` cases in `tests/screen/git/test_changes_screen.lua` against populated `billing`, compare byte-identical copies under `tests/screen/git/` of the approved real-glyph render text, and assert real extmark groups with the masks and legends from design.md; see them fail
- [x] 7.2 Adjust the panel and diff-view rendering, Tree-sitter colours and indent guides until both approved scenario bounds pass, then compare the real captures with `make colorize FILE=openspec/changes/git-changes-tree/design.md`
- [x] 7.3 Run `make test FILE=tests/screen/git/test_changes_screen.lua CASE="Changes panel"` and see it pass

## 8. Gate
- [x] 8.1 Run `make trace` and confirm every scenario of this change is tested with no orphans or duplicates
- [x] 8.2 Run `make test CAPS=find-action,file-tree,git` and see it pass
- [x] 8.3 Run `make check` and `openspec validate git-changes-tree --strict` and see both pass

## Agent decisions

- `model.rows` returns flat display-order rows because rendering, cursor movement and folds consume the same ordered panel model.
- `model.rows` returns a `capped` flag so the view can own the warning while the model stays pure.
- Checkbox fields carry the approved glyphs so renderers consume one model-derived index state without a second mapping.
- Changes panel action titles use concise verbs (`Open`, `Commit`, `Push`) so generated descriptions stay `Changes: <Title>`.
- Fold state is a per-panel set of collapsed model fold IDs, so refreshes can rebuild rows without losing user choices.
- Changes panels use their buffer IDs as shared-watch owners, avoiding collisions with another left view in the same tab.
- Panel refreshes debounce for 50 ms, matching the diff-selection cadence while coalescing writes and git-dir bursts.
- The shared editor-window selector also exports its eligibility predicate so Changes can mirror orphan detection without duplicating tool-window exclusions.
- Repository-relative staging needed no production edit because task 4a already rooted both status and mutation calls and propagated their failures.
- Batch staging filters one full fresh status snapshot because Git status has no pathspec-from-file option and destination-only status loses rename origins.
- Diff selection uses its own per-panel timer so refresh coalescing cannot cancel the 50 ms cursor debounce.
- Project-tree toggle checks the already-loaded Changes module before handoff, avoiding a new feature load when no panel exists.
- Binary detection uses Git numstat while conflict content uses its porcelain status, keeping both kinds in unnamed read-only buffers without guessing from file bytes.
- Panel diff loading reports an initially unloaded file buffer to its owning panel, so close can unload clean owned buffers without touching preloaded or modified buffers.
- Revert uses `vim.ui.input` so the standalone Changes panel keeps the existing prompt without requiring neo-tree UI setup.
- Unborn-HEAD revert reuses the added-file path because every staged path without a commit is added, and that path already runs literal-pathspec `rm --cached`.
- A diff load outdated only by a refresh reloads the row under the panel cursor, because git-dir refreshes during `]f` otherwise drop the selection's only show.
- Refresh line stats come from plumbing `git diff-index -M --numstat -z HEAD` beside status: porcelain `git diff` rewrites the index under `index.lock` in a stat-dirty checkout, racing panel stage and revert; its failure on an unborn HEAD yields no stats without a separate HEAD probe.
- Screen legends name nvim-web-devicons' `DevIconTypeScript` for `.ts` icons: the installed plugin defines no `DevIconTs`, and both name the same `#519aba` icon colour.
- Render unit cases expect the model's unchecked glyph `󰄱`: the `☐` they pinned is design.md's stand-in, and the renderer now draws each row's index state.
- Task 7 screen comparison follows the auditor's task 7 Decision: the panel columns keep the full approved masks and the byte-identical render text copies under `tests/screen/git/`, the editor pane equals a regular window, and Proposed B's scenario states that bound.
- Screen cases check devicon cells against the glyph nvim-web-devicons defines for the masked `DevIcon*` group: design.md's `◆` stand-in is a devicon, and the mockup's README glyph for `notes.md` is not the `.md` icon the plugin and the approved project-tree render draw.
- The regular-window reference puts a fixed-width 35-column scratch window where the panel goes: Proposed A captures it before the panel opens, Proposed B after closing the panel, showing the panel's own diff spec with `diff.view.show`, so only the panel's presence differs between the two screens.
- Screen captures wait for gitsigns hunks and Tree-sitter parses, because Neovim 0.12 highlights asynchronously and both screens must carry the same plugin state.
- A cursor move off the loading row drops its in-flight diff at once rather than when the debounce ends, so a late load never replaces another view of the same path.
