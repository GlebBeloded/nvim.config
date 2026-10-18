## Why

Kind: feature
Depends: file-tree-nesting

The new project tree lists everything on disk, so build output, dependency folders and secrets files (`bin/`, `web/node_modules/`, `.env`) crowd the real sources. IntelliJ hides what the project ignores and shows it on demand. The user wants ignored entries hidden by default, with no hint or summary row, only a Show Ignored action in the file tree, and ignored entries shown in grey italic when they are shown.

## What Changes

- **What is ignored** (`lua/gleb/file_tree/ignore.lua`):
  - untracked paths git marks `!` in the existing async porcelain-v2 status request, extended with `--ignored=matching`;
  - everything below an ignored folder;
  - entries that match a glob of the new `ignore` list in `settings/file_tree.json`.
  - Tracked files are never ignored. The `.git` folder, which `file-tree-view` already hides, stays hidden even with Show Ignored.
- **Hidden by default.** Ignored entries are left out of the listing before nesting, with no hint or summary row. Following the current file never reveals a hidden ignored file.
- **Show Ignored:** a new toggle action, `file_tree.show_ignored` ("Show Ignored", category Project like every `file_tree.*` action, scoped to the `gleb-file-tree` filetype), bound to `I` in `settings/keymap.json` and listed in Find Action with its state glyph. The state persists in `stdpath("state")/file_tree/view.json` and applies to every open tree.
- **Look:** shown ignored rows draw their name and icon with the new `FileTreeIgnored` group (palette grey, italic). They get no git colour and never tint their folder.
- **No descent:**
  - `file_tree.unfold_all` leaves ignored folders collapsed.
  - An expanded ignored folder lists its children as ignored without asking git.
  - Hidden ignored folders are never listed or watched.
- **Outside a git repository** only the `ignore` globs apply, and no git command runs.
- **Render:** "Proposed — after Show Ignored" (the approved `ign_dim` screen).

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `file-tree`: added "File tree ignored entries", "File tree Show Ignored action", "File tree ignored look", "File tree ignored folders" and "File tree ignored screen". No existing requirement or scenario changes.

## Impact

- Code:
  - New: `lua/gleb/file_tree/ignore.lua` (pure: glob and ignored-set matching), `lua/gleb/file_tree/state.lua` (Show Ignored, persisted in `stdpath("state")/file_tree/view.json`), the `FileTreeIgnored` group.
  - Changed:
    - `settings/file_tree.json` (`ignore` list) and `settings.lua` (validates it);
    - `git.lua` and `model.lua` (the existing async status query also returns a generation-scoped ignored set);
    - `model.lua` (filter before nesting, no descent);
    - `render.lua` (ignored groups);
    - `view.lua` (follow skips hidden files);
    - `actions.lua` (`file_tree.show_ignored`);
    - `settings/keymap.json` (`I` for it).
- Tests:
  - integration: `tests/integration/file-tree/test_ignored.lua` on the `treeproj` fixture.
  - screen: `tests/screen/file-tree/test_ignored.lua`.
- Fixture: `treeproj` gains `bin/server`, `web/node_modules/left-pad/index.js` and `.env`, all untracked, and its `.gitignore` holds `bin/`, `node_modules/`, `.env` and `*.log` (design.md Decision 7).
- Plugins: none added or removed.
- Core keymaps: none. `I` is a buffer-local key of the new tree's filetype only.
- Unchanged scenarios:
  - `diff: Diff view embedding` still holds because the new Show Ignored state and action do not change `gleb.diff.view.show`.
  - `file-tree: Dotfiles and gitignored files are listed` still holds: it is about neo-tree's filesystem source, which this change doesn't touch and which stays until `tree-diff-cutover`.
  - `bufferline: tabs start after the open project tree` still holds because filtering tree rows does not change the project-tree window width or tabline offset.
- Out of scope:
  - A hidden-count hint or summary row (the user declined it).
  - IntelliJ's separate "excluded" state, and per-folder exclude actions.
  - Global excludes outside git (`core.excludesFile` is honoured through git only).
  - Nested repositories and submodules: their own ignore files are not consulted.
  - Ignoring tracked files.

## Decision (user, 2026-10-17)

- Decision page: https://claude.ai/artifact/P7naTb7oU7Ke52P1QNkEdH
- Ignored: hidden by default, no hint or summary row, only a Show Ignored action: "I don't think I need hints for that, just Action Show Ignored in File tree".
- Shown in grey italic (picked the `ign_dim` render over IntelliJ's olive).
- Ignored = .gitignore + .git + user patterns.

## Decision (auditor, 2026-10-18, pre-implementation audit)

- Query: no `ls-files`. The shipped status call becomes `git --no-optional-locks -C <root> status --porcelain=v2 -z --untracked-files=normal --ignored=matching` (one work-tree walk, measured ≈ plain status; traditional `--ignored` is 3× slower). `model.parse_status` maps `!` records into a separate ignored set in `FileTreeGitRoot` (same generation, in-flight and dirty flags, paths through the shipped prefix stripping), never into `status` or `folder_status`. "reads git status without optional locks" becomes MODIFIED; a task 0 updates its argv and runs `make test CAPS=file-tree,picker` before any ignored code. The tree root and its ancestors are never ignored; a folder whose children are all ignored is listed and shows none of them.
- Model: `model.rows(tree, expanded, opts)` with `opts = { status, ignored, show_ignored, matcher }` at every call site (draw, `expand_directory`, `unfold_all`), so caps count only listed rows. "Ignored" passes down from the parent folder (no per-row ancestor walk); globs compile once per settings generation. Compaction runs on filtered children and never goes into or past an ignored folder (`web/node_modules` stays `node_modules`); ignored folders get no `fs.scan` and no watch until expanded. The nest cache key adds an ignored-set generation (bumped only when the set changes) and `show_ignored`.
- Hidden-path gate: one `is_hidden(view, path)` helper checks follow, reveal, `select_created` and `refresh_moved` before `expand_to`; a hidden ignored target never expands folders or nests, never writes `expanded.json`, never moves the cursor. Ignored wins over nesting's "follow expands the nest". When the cursor's row disappears (toggle or refresh) the cursor goes to the nearest listed row above.
- First paint: only when watch's `toplevel` is set, the first request skips the debounce and drawing waits until the result arrives or 300 ms pass; never on later refreshes, never outside git. The brief flash of newly built ignored entries (watcher before git) is an accepted risk.
- Tests: the screen case compares text verbatim with `tests/screen/file-tree/ign_proposed.ansi` (a byte-identical copy) plus real extmark groups (no mask, no self-blessed screenshot, nothing read from `openspec/`); the child gets `H.GIT_ENV`. Scenarios: a file under hidden `node_modules` is not revealed; created or renamed into an ignored path; root inside an ignored folder; nested `.gitignore` and negation; an untracked folder with only ignored content; two tabs (repo and `web/`) under a symlinked `/private/var` root; cursor on an ignored row when Show Ignored turns off. Task 2.2's `.git` drop is already shipped (`visible_entries`): removed. Splits: 2.2 → 2a query, 2b first paint, 2c gate; 4.2 → 4a look, 4b no descent.

## Agent decisions

- **`.git` is never listed.** `file-tree-view` already hides it, and Show Ignored does not show it either, as in IntelliJ. The approved `ign_dim` render shows no `.git` row after Show Ignored either.
- **Git query:** the auditor's single `git --no-optional-locks -C <root> status --porcelain=v2 -z --untracked-files=normal --ignored=matching` request supersedes the earlier separate `git ls-files` choice; `!` records populate only the ignored set.
- **Globs** use `vim.glob.to_lpeg`, a built-in. A pattern without `/` matches a name at any depth, and one with `/` matches the path from the tree root, as in `.gitignore`.
- **First paint** waits up to 300 ms for the first ignored result, so `node_modules` doesn't flash and vanish.
- **Ignored folder icons** use `FileTreeIgnored` (grey0) like file icons. The approved mockup drew folder icons a shade lighter (grey1). One group keeps "grey icons" simple, and the difference is 2 cells.
- **Show Ignored is scoped** to the tree's filetype, so the global `I` stays free. Find Action lists it while the tree is focused.
- **Unfold all skips ignored folders**, so `zR` never walks `node_modules`.
