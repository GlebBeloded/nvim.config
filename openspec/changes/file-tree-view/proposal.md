## Why

Kind: feature
Depends: diff-view-actions

The user wants a project tree that looks and behaves like IntelliJ's Project view ("I'm used to Idea"): name colour only for git status, changed folders tinted, compact single-child folder chains, no indent guides, a bold project root row. neo-tree cannot draw that: it has no folder tint, no compact chains, and draws guides and right-hand git symbols (Current render in design.md). The later changes need a tree they own: file nesting (`file-tree-nesting`), Show Ignored (`file-tree-ignored`) and the commit tree (`git-changes-tree`) reuse its model, rows and colours.

This change adds the new tree beside neo-tree. It opens only from new, unbound actions, so every neo-tree key keeps working until `tree-diff-cutover` rebinds `<A-e>` and removes neo-tree.

## What Changes

- **New project tree** in `lua/gleb/file_tree/`:
  - `model.lua` (pure): entries to rows, sort, compact chains, git status parsing and folder tint.
  - `fs.lua` (directory scans), `git.lua` (async status), `watch.lua` (libuv watchers), `expanded.lua` (expanded folders per root), `render.lua` (lines, extmarks, highlight groups), `view.lua` (window, buffer, autocmds).
  - neo-tree's setup moves unchanged from `init.lua` to `neo_tree.lua`. `init.lua` then only requires `neo_tree` and `view` (rule 1.1).
- **Window.** Left-docked, 35 columns, `winfixwidth`, filetype `gleb-file-tree`, at most one per tab page. It closes before the last editor window quits, as neo-tree's `close_if_last_window` does.
- **Rows** (IntelliJ look, approved render `ft_idea` without nesting):
  - A root row: expander, open folder icon, the project name in bold and its `~` path in grey.
  - Folders first, then files. Names compare case-insensitively.
  - Devicons for files. No indent guides. `.git` is hidden.
- **Compact chains.** A folder whose only entry is a folder shares its row (`cmd/server`, `.github/workflows`). The row expands and collapses the last folder of the chain.
- **Git colours.** `git --no-optional-locks status --porcelain=v2 -z` runs asynchronously and throttled. File names are coloured modified, added, untracked, renamed or conflicted. A folder takes the strongest status below it: conflict, then modified, then added, then untracked.
- **Live.**
  - Follows the current file.
  - libuv watchers on the root, every expanded folder and the git dir.
  - Re-roots on `DirChanged`.
  - Expanded folders persist per root in `stdpath("state")/file_tree/expanded.json`.
- **Actions** (`file_tree/actions.lua`, category `Project`):
  - Global and unbound: `file_tree.toggle`, `file_tree.reveal`.
  - Bound in `settings/keymap.json` to the `gleb-file-tree` filetype:
    - `file_tree.open` `<CR>` `o` `l`, `file_tree.close_node` `h` `<BS>`
    - `file_tree.open_split` `s`, `file_tree.open_vsplit` `v`, `file_tree.open_tab` `t`, `file_tree.close` `q`
    - `file_tree.toggle_fold` `za`, `file_tree.fold_all` `zM`, `file_tree.unfold_all` `zR`
- **Bufferline.** `bufferline.lua` offsets the tabs for the `gleb-file-tree` filetype too.
- **Find Action.** `find_action/assign.lua` drops the `file_tree` → neo-tree entry from `ADAPTER_PLUGINS`. A shortcut assigned to a new `file_tree.*` action then applies at once. The `test_assign.lua` adapter fixture moves from `file_tree.open` to a `neo_tree.` id.
- **Fixture.** `tests/fixtures/build.sh` gains `treeproj`, the design fixture as a real repo, with modified, staged-added, untracked and ignored files (design.md, Fixture).

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `file-tree`: added requirements for the project tree: window and toggle, rows, compact chains, opening, folds, git colours, following, live updates, persistence, keys and the approved render. The neo-tree requirements stay until `tree-diff-cutover`.
- `bufferline`: added "Tabline offset for the project tree".

## Impact

- Code:
  - New: `lua/gleb/file_tree/{model,fs,git,watch,expanded,render,view,neo_tree}.lua`.
  - Changed: `lua/gleb/file_tree/init.lua`, `lua/gleb/file_tree/actions.lua` (new actions appended), `lua/gleb/bufferline.lua`, `lua/gleb/find_action/assign.lua`, `settings/keymap.json` (view-scoped keys only), `tests/fixtures/build.sh`.
- Tests:
  - unit: `tests/unit/file-tree/test_model.lua` (rows, sort, chains, porcelain v2 parsing, tint).
  - integration: `tests/integration/file-tree/test_project_tree.lua`, `test_project_git.lua`, `test_project_live.lua`.
  - screen: `tests/screen/file-tree/test_project_tree.lua`, `tests/screen/bufferline/` (new offset case).
- Plugins: none added or removed. nvim-web-devicons (installed) gives the file icons. The tree is our own code by user decision. Alternatives considered for the base:
  - nvim-tree.lua (8.7k stars, pushed 2026-10-16) and neo-tree have no folder tint or compact chains in their renderers.
  - oil.nvim (7.0k stars, pushed 2026-10-12) is a buffer editor, not a sidebar tree.
- Core keymaps: none. `<A-e>` and `<A-G>` keep opening neo-tree. The new keys are buffer-local to `gleb-file-tree`.
- Unchanged scenarios:
  - `find-action: Adapter assignment reports deferred application` still holds: the fixture adapter action keeps an adapter prefix (`neo_tree.`), so the message is unchanged.
  - `find-action: Saved shortcut applies immediately` still holds, and now also for the new `file_tree.*` actions.
  - `keymaps: File tree and git panel toggles` still holds: `<A-e>`/`<A-G>` still run `tree.toggle_filesystem`/`tree.toggle_git_status`.
  - `bufferline: tabs start after the open tree` still holds: the neo-tree offset entry is kept.
  - `autocommands: q closes special buffers through an action` still holds: the tree's `q` is a buffer-local mapping of the `gleb-file-tree` buffer only.
  - `git: q closes diffview from file panel` still holds: diffview's keys and filetypes are untouched; the new keys are local to `gleb-file-tree` buffers.
  - `git: s stages entry from file panel` still holds: the tree's `s` exists only in `gleb-file-tree` buffers.
  - `git: Enter confirms message` still holds: the commit popup's buffer and keys are untouched.
  - `git: Enter on empty buffer does nothing` still holds: the commit popup is untouched.
  - `git: Enter on placeholder does nothing` still holds: the commit popup is untouched.
  - `git: Enter drops comment lines` still holds: the commit popup is untouched.
  - `git: q discards popup` still holds: the commit popup is untouched.
  - `references: Tests key cycles grouped, hidden and mixed` still holds: the Find Usages view's `t` is untouched; the tree's `t` is local to `gleb-file-tree`.
  - `references: Mixed tests without folders is a flat list` still holds: Find Usages is untouched.
  - `references: Grouping persists across sessions` still holds: Find Usages state is untouched; the tree keeps its own state file.
  - `shortcuts: Ctrl+Return reaches Neovim as <C-CR> from a real key press` still holds: no global key or terminal mapping changes; `<CR>` is only mapped in the tree buffer.
- Out of scope:
  - File operations (`file-tree-ops`), nesting (`file-tree-nesting`), ignored files and Show Ignored (`file-tree-ignored`).
  - Rebinding `<A-e>`, the netrw/directory hijack and neo-tree removal (`tree-diff-cutover`). Until then `:edit <dir>` still opens neo-tree.
  - Diagnostics in the tree, drag and drop, a float project view, multiple roots.

## Decision (user, 2026-10-17)

- "I'm used to Idea".
- File tree: sidebar 35 columns. Git status is name colour only, and changed folders are tinted (IntelliJ). No indent guides. Compact single-child folder chains (IntelliJ "compact middle packages").
- Approved look: `ft_idea` (= `nest_chevron`). Nesting comes in `file-tree-nesting`, so this change renders it without nest chevrons.
- "Also I need fold all/unfold all actions in file tree".

## Decision (auditor, 2026-10-17, pre-implementation audit)

- Watching and isolation: watch every compact-chain member and every folder whose scan feeds a row; cache scans until a watcher invalidates them. Git and watch state are keyed per root with handle refcounts across tabs; view state, buffer name and autocmds per tabpage handle (never tabnr, never a group-wide clear). A two-tab scenario.
- One path normaliser `normalize(path)` (fs_realpath, else the nearest existing parent) for root, buffers, git toplevel and HOME shortening; a folder is cut at the first already-seen realpath. Scenarios: a root reached through a symlink, a symlink loop (`loop -> .`), a deleted file during follow and during toggle, an expanded folder deleted while open (cursor clamped, entry pruned, handle closed), a `chmod 000` folder, a directory buffer (not followed); none raises or notifies.
- Window hygiene: open/split/tab/new editor window run from the target editor window (skipping neo-tree, quickfix, terminal, float and diff-view windows), never the tree. The tree window sets `foldenable=false`, `foldmethod=manual`, `statuscolumn=""` and detaches ufo; a file opened into the tree window moves to the editor window; the cursor is hidden only in `n`/`v` modes from an original `guicursor` saved once. QuitPre counts neo-tree windows as trees too; `:close` and both-trees scenarios; the v/s/t scenarios assert the new window has `number` and no `winfixwidth`.
- Spec and tasks: add "toggle reveals the current file" to "Project tree window"; move QuitPre into task 2; split task 2 into 2a (neo-tree move, `render.lua`) and 2b (`view.lua`, toggle, QuitPre, bufferline), task 5 into 5a (follow/reveal and the deleted-file cases), 5b (`watch.lua`, chain splits), 5c (`expanded.json` per-root merge with atomic write, re-root incl. git worktrees via `rev-parse --absolute-git-dir`). Folder status is precomputed once per git result; manual expand and watched folders are capped.
- Render proof: the screen case asserts the tree window's text rows verbatim against `renders/f1_proposed.ansi` with real glyphs as well as the reference screenshot, which is reviewed against that file before commit; integration tests assert each row's extmark groups; `DevIcon*` and every `FileTree*` colour are pinned with `expect_hl_colors`. `git-changes-tree` reuses `model.parse_status`.

## Agent decisions

- **Ignored entries until `file-tree-ignored`:** the tree lists them like any other entry and hides only `.git`. The approved render is reproduced on a fixture copy without its ignored entries, so the screen scenario keeps holding once they are hidden by default.
- **Compact chains** merge whatever the expansion state, as IntelliJ does. Expansion belongs to the last folder of the chain.
- **Folder tint precedence:** conflict, then modified (renamed and deleted count as modified), then added, then untracked. The root row is never tinted.
- **Open on a folder toggles it** (IntelliJ Enter). `s`/`v`/`t` on a folder do nothing.
- **`za` on a file** collapses the folder that contains it, like Vim's `za` on a fold.
- **Unfold all** stops after 5000 rows with a WARN, so a huge folder cannot freeze the editor.
- **Persistence:** expanded folders are saved per root in the state dir, because IntelliJ keeps them per project.
- **Statusline:** unchanged. The language chip shows `gleb-file-tree` while the tree is focused, as it shows `neo-tree` today.
- **Cursor:** hidden while the tree is focused. The cursor line marks the selection.
