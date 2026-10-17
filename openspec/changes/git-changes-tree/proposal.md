## Why

Kind: feature
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

## Agent decisions

- **Partly staged files** show a mixed checkbox, and `<Space>` on one stages the whole file, as clicking IntelliJ's partial checkbox includes the file. Unstaging needs a second press.
- **Revert** keeps an added file on disk (`git rm --cached`) and does nothing on an unversioned file, as IntelliJ's Rollback. Failures now notify `Revert failed: <stderr>`, which neo-tree's revert silently ignored.
- **`<CR>`** opens the file and keeps the panel, as IntelliJ's F4 leaves the Commit window open. The neo-tree flow switched to the filesystem tree instead.
- **`changes.review`** is a second entry point, so Cmd+G keeps meaning "review my changes with a diff" after the cutover, while `<A-G>` only toggles the panel.
- **Nests start expanded** here (the approved render shows them open), unlike the project tree, so no change is hidden in a review.
- **Commit and push run in the repository root,** not the cwd, like staging already did.
- **Renders:** the statusline chip names the filetype `gleb-changes` (the mockup said `changes`), as `file-tree-nesting` did for `gleb-file-tree`. The panel columns are the approved render, cell for cell.
