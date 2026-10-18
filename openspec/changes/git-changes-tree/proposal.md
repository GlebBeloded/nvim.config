## Why

Kind: feature
Adopt: loop/git-changes-tree-20261018-161749
Depends: file-tree-ignored

Reviewing and committing changes today goes through neo-tree's git status source: a flat-ish tree with status symbols, where each `j`/`k` opens a second tab with codediff and a copy of the tree, held in place by a focus guard. Cmd+G opens a third flow, differ.nvim, with its own panel. The user is used to IntelliJ and picked its commit tool window: "Changes" and "Unversioned Files" roots, files grouped by directory, a checkbox that is the index, tests nested under their file, `+/-` per file, and the selected file's diff in the editor area, in the IntelliJ-style diff view this queue builds (`diff-view`, `diff-view-actions`).

## What Changes

- **Changes panel** `lua/gleb/git/changes/`: a 35-column left sidebar, filetype `gleb-changes`, matching the approved render (`ch_idea`):
  - roots `Changes <n> files` (tri-state checkbox) and `Unversioned Files <n> files`;
  - files grouped by directory, single-child chains compacted (`internal/billing`), a file count per directory;
  - file names coloured by status only (`FileTreeGit*`), a staged checkbox per file (checked, mixed, empty);
  - tests and other children nested under their file by the project tree's nesting rules (`file-tree-nesting`), expanded;
  - right-aligned `+N -M` from `git diff --numstat HEAD`; long names end with `…`.
- **Diff view in the editor area.** Moving the cursor onto a file row shows that file in the diff view (HEAD left, working tree right) in the editor window after 50 ms, one reused view, focus kept in the panel. The view's next-file key steps to the panel's next file.
- **Actions** (all from `settings/keymap.json`, view-scoped to `gleb-changes`): Space stages or unstages (file, directory or root), A stages all, Enter opens the file (folds on other rows), X reverts with the existing confirmation text, gc opens the existing AI commit popup, P pushes with the existing notifications, q closes, za folds.
- **Entry points** `changes.toggle` (panel) and `changes.review` (panel plus the diff of the current file), registered for Find Action and unbound: `tree-diff-cutover` gives them Alt+Shift+G and Cmd+G.
- **One left tool window:** the changes panel and the project tree (`file-tree-view`) replace each other, as Project and Commit do in IntelliJ.
- **Highlights:** `ChangesRoot`, `ChangesCount`, `ChangesCheckbox`, `ChangesStatAdded`, `ChangesStatRemoved` from the palette; names and folders reuse `FileTreeGit*` and `FileTreeFolder*`.
- **Fixture** `billing` in `tests/fixtures/build.sh` (design.md, Fixture): the approved render's repository and numbers.

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `git`: added "Changes panel window", "Changes panel outside a repository", "Changes panel rows", "Changes panel status colours", "Changes panel staging checkbox", "Changes panel staging toggle", "Changes panel stage all", "Changes panel line stats", "Changes panel nesting", "Changes panel diff view", "Changes panel review", "Changes panel diff file navigation", "Changes panel open and close", "Changes panel revert", "Changes panel commit", "Changes panel push", "Changes panel refresh", "Changes panel keys", "Changes panel shares the left side" and "Changes panel screen". Nothing is modified or removed; the neo-tree git status requirements stay until `tree-diff-cutover`.

## Impact

- Code:
  - New: `lua/gleb/git/changes/{init,model,render,git,view,actions,highlights}.lua`.
  - Changed: `lua/gleb/git/actions.lua` (appends the `changes.*` actions), `lua/gleb/git/init.lua` (requires `gleb.git.changes` after gitlink), `settings/keymap.json` (eight view-scoped `changes.*` entries), the project tree's open path in `lua/gleb/file_tree/` (closes the changes panel first), `tests/fixtures/build.sh` (`billing`).
- Tests:
  - unit: `tests/unit/git/test_changes_model.lua` (porcelain v2 and numstat parsing, grouping, compaction, nesting, sort, checkbox states) and `test_changes_render.lua` (columns, stats, `…` cut).
  - integration: `tests/integration/git/test_changes.lua` (window, staging incl. the cwd and suffix cases, revert, commit, push, refresh, diff view link, keys) on `dirty`, `billing` and temp repos.
  - screen: `tests/screen/git/test_changes_screen.lua` for "Proposed A" and "Proposed B".
- Plugins: none added or removed. diffview, gitsigns and nui.nvim (the commit popup) are used as they are.
  - Alternatives checked: diffview.nvim's file panel (Staged/Changes sections, no checkboxes, its own diff layout), neo-tree's git status source (today's flow), fugitive's `:Git` status buffer (text list) and lazygit (external TUI). None draws IntelliJ's commit tree or uses the diff view of `diff-view`, which the user wants to own ("I want to own ui 100%").
- Core keymaps: none. `changes.toggle` and `changes.review` stay unbound until `tree-diff-cutover`; the new keys are buffer-local to `gleb-changes`.
- Unchanged scenarios: neo-tree's git status source, differ and codediff keep working unchanged until `tree-diff-cutover` removes them.
  - `file-tree: Space stages an unstaged file` still holds: the neo-tree action and its binding are untouched; the new panel has its own `changes.toggle_stage`.
  - `file-tree: X reverts a file after confirmation` still holds: neo-tree's revert is untouched.
  - `file-tree: gc commits confirmed message` still holds: `gleb.git.ai_commit` is reused, not changed.
  - `git: Commit popup mappings come from git actions` still holds: the popup is opened, not changed.
- Out of scope:
  - Hunk and line staging (`diff-view-actions` owns the per-change checkbox).
  - Change lists, shelve, amend, commit history, a commit message field inside the panel.
  - A "Merge Conflicts" root and conflict resolution (diffview stays the merge tool).
  - Ignored files in the panel and a file watcher (refresh is on own git commands, writes and focus).

## Decision (user, 2026-10-17)

- Decision page: https://claude.ai/artifact/P7naTb7oU7Ke52P1QNkEdH
- Changes panel: picked "IntelliJ commit tree (Changes / Unversioned Files roots, grouped by directory, checkbox = staged, tests nested, +/- per file)", the approved render `ch_idea`.
- Diff: "I like IDEA IDE diff more"; panes "Aligned, IntelliJ chrome" (`diff2_aligned`).
- File tree: "sidebar 35 columns"; nesting by "the full recommended rule set".
- General: "I'm used to Idea".

## Decision (auditor, 2026-10-18, pre-implementation audit)

- Parsing: extract `gleb.file_tree.model.parse_status_records(z)` → `{ kind, xy, sub, path, orig }` (orig from the extra NUL field of `2` records) and make `parse_status` (and the ignored set from `file-tree-ignored`) a wrapper; the changes model uses only it. `R`/`C` are renamed (orig kept), `.A` added, `u` conflict, the same path under both roots two rows; `? dir/` or a `S…` submodule are rows with no diff, no `bufload` and no `<CR>` (notify). Numstat is keyed by status records (missing → no stats); status runs with `--no-optional-locks`; model and grouping are single-pass; the panel caps rows like the project tree.
- Staging safety: every git call uses `git --literal-pathspecs`. File, directory and root decisions come from one fresh `git status --porcelain=v2 -z -- <paths>` (`--pathspec-from-file=- --pathspec-file-nul` above 100 paths), never row state or per-file processes. `<Space>` on an unmerged file notifies `Stage failed: resolve conflicts in the merge tool` and runs nothing (`A` keeps `git add -A`). Renames unstage with `reset -- new old` and revert with `checkout HEAD -- old` + `rm --cached -- new`; revert on unborn HEAD uses `rm --cached`. Scenarios for `[ab].txt`, unmerged, rename and unborn HEAD.
- Diff link: the panel builds the full `gleb.diff.view.Spec` asynchronously with generation checks (`root`, repo-relative `relpath`, `filetype`, `head_final_newline`, left from `HEAD:<orig or path>`); `actionable` is false for added, untracked, deleted, binary, unmerged and submodule files; deleted and binary files get a read-only buffer, never `bufadd`. When `show` returns nil the panel closes its own view and notifies `No content changes: <name>`; a same-path move does not re-show. The panel holds its own view handle and closes only that one (editor-buffer restore stays in `windows.restore`); `on_next_file` re-focuses the new view's `right_win` when called from a diff window; buffers the panel loaded are unloaded on close when unmodified; a public `diff.view.refresh_index(view)` runs after every panel git command.
- Windows and isolation: state `by_tab` with per-panel timers and generations, buffer- or window-scoped autocmds. The editor window comes from the project tree's eligible-editor helper, exported with `gleb-changes` added to its exclusions and re-validated before each `show`; QuitPre and orphan-close follow the file tree; root and buffer paths go through `fs.normalize`; refresh also subscribes to `watch.lua`'s git-dir event (diff-view hunk staging and gitsigns reach the panel). `ai_commit.show_commit_input(on_commit, { root })` runs `git diff --cached` in the root. Scenarios: two tabs, a symlinked `/private/var` root, toggling from the project tree, `]f` focus, a stale index after hunk staging.
- Tests and tasks: screen cases compare against byte-identical copies under `tests/screen/git/` plus real extmark groups; nothing read from `openspec/`, no self-blessed screenshot (drop 7.3). Changes tests load the default nesting rules explicitly. `changes.*` actions set no `plugin`; a task adds `changes.toggle` and `changes.review` to Find Action's approved list and runs `make test CAPS=find-action,file-tree,git`. Split task 3 into 3a (window, toggle, outside a repository), 3b (keys and catalog), 3c (folds and refresh), 3d (left-slot swap), and task 5 into 5a (show, debounce, untracked, deleted, no-diff), 5b (review and `]f`), 5c (Enter, `q`, project-tree swap).

## Agent decisions

- **Partly staged files** show a mixed checkbox, and `<Space>` on one stages the whole file, as clicking IntelliJ's partial checkbox includes the file. Unstaging needs a second press.
- **Revert** keeps an added file on disk (`git rm --cached`) and does nothing on an unversioned file, as IntelliJ's Rollback. Failures now notify `Revert failed: <stderr>`, which neo-tree's revert silently ignored.
- **`<CR>`** opens the file and keeps the panel, as IntelliJ's F4 leaves the Commit window open. The neo-tree flow switched to the filesystem tree instead.
- **`changes.review`** is a second entry point, so Cmd+G keeps meaning "review my changes with a diff" after the cutover, while `<A-G>` only toggles the panel.
- **Nests start expanded** here (the approved render shows them open), unlike the project tree, so no change is hidden in a review.
- **Commit and push run in the repository root,** not the cwd, like staging already did.
- **Renders:** the statusline chip names the filetype `gleb-changes` (the mockup said `changes`), as `file-tree-nesting` did for `gleb-file-tree`. The panel columns are the approved render, cell for cell.

## Decision (auditor, 2026-10-18, after the task loop)

- `gc` in the Changes panel commits at once: the panel's mapping is buffer-local with `nowait`, so a global mapping
  starting with `gc` never makes it wait for 'timeoutlen'. The test types plain `gc` (no `<Ignore>` after it) and
  asserts the commit popup opens without waiting.
- Tests never stub production functions (`changes.commit = function() end` in the 6c test goes); a case drives the real
  module.
- Task 5b's two attempts are in tasks.md's `## Stuck` text; `$ARTIFACTS_DIR/stuck-attempt.diff` now holds task 7's
  attempt only, so the 5b fix pass starts from the Stuck text, not from that diff.
- (task 7 screen cases) The Changes screen cases assert the panel's columns (1–36 at 120 columns: rows, checkboxes,
  expanders, names, stats) against the approved renders' full colour masks, cell for cell. The editor/diff pane to the
  right shows content owned by treesitter, indent-blankline and the shipped diff view (`diff: … screenshot` cases cover
  it); there the case asserts it equals the same file rendered in a regular window of that width, not the approved
  render's highlight of each token. Never edit editor plugins' state (ibl setup, tabstop) from the panel to match a render.

## Rejected run
Run on `loop/git-changes-tree-20261018-161749` was rejected by the judge:
- review: test weakened
- fix loop exhausted with gates still red: review
- review findings:
  [must-fix] The last fix pass (98415b9a) dropped the only check that `gc` runs at once. Before, `eq(child.lua_get("CommitRoot"), …)` was read straight after `child.type_keys("gc")`, so a `gc` that waited for 'timeoutlen' failed the case (pass 8 counted this as the nowait coverage). Now tests/integration/git/test_changes_actions.lua:118-124 and :303-308 poll `vim.wait(ASYNC_MS=10000, …)` for the popup title. 'timeoutlen' is 1000 ms (lua/gleb/options.lua:20), so if `nowait` is removed from lua/gleb/git/changes/actions.lua:58 the popup still opens after 1 s and both cases stay green. The auditor Decision (proposal.md:92-94) requires asserting that "the commit popup opens without waiting". Fix: right after the plain `gc`, assert that the nui popup window exists, either with no wait or with a bound well under 'timeoutlen' (e.g. `child.wait(…, 200)`). `popup:mount()` runs synchronously (lua/gleb/git/ai_commit.lua:159). Earlier passes did not miss this: the commit that removed the check is the newest one.
  [must-fix] The same commit also removed the check that the popup gets `{ root = root }`, which is the delta SHALL at specs/git/spec.md:309 ("staged-diff generation … run in the panel repository"). Both cases `cd` to `vim.fs.dirname(dir)` (test_changes_actions.lua:117), which is the parent of a `tempname()` repo (tests/helpers.lua:281) and is not a git repo. If `opts.root` were dropped, `git diff --cached` there would print nothing, `build_prompt` would return nil, and the popup woul
- note: loop: sandbox: Lume still reports nvim-e2e unknown while its lume run process is alive, after one restart; giving up (/Users/hlebbeladzed/.cache/nvim-e2e-sandbox/vm.l
