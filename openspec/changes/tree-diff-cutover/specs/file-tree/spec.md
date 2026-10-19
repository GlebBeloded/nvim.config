## ADDED Requirements

### Requirement: Project tree opens for a directory buffer
With no project tree open, editing a directory SHALL open and focus the sidebar rooted there, replace the directory buffer's window with an empty buffer and wipe the directory buffer. With a tree already open, entering a directory buffer SHALL focus that tree without changing its root or cursor. netrw SHALL not load.

#### Scenario: Directory argument opens the project tree
- **WHEN** `:edit <dir>` runs for a directory `docs` that contains `workflow.md`
- **THEN** the current window has filetype `gleb-file-tree`, its root row names `docs` and a `workflow.md` row follows, no window shows a buffer named `<dir>`, and no buffer has filetype `netrw`

#### Scenario: netrw is not loaded
- **WHEN** Neovim starts with the full config and `VeryLazy` has fired
- **THEN** `:Explore` is not a command (`vim.fn.exists(":Explore") == 0`) and `lazy.nvim`'s `performance.rtp.disabled_plugins` contains `netrwPlugin`

#### Scenario: Directory buffer focuses an open project tree
- **WHEN** the project tree rooted at a copy of `treeproj` has its cursor on `go.mod` and `:edit internal` runs in its editor window
- **THEN** the existing project tree is current, its root is still `treeproj`, its cursor is still on `go.mod`, and no directory buffer remains

#### Scenario: Directory buffer entered from project tree focuses it
- **WHEN** the project tree rooted at a copy of `treeproj` has its cursor on `go.mod` and `:edit internal` runs in the project-tree window
- **THEN** the existing project tree is current with the same root and cursor, the editor still shows its previous file, and no directory buffer remains

#### Scenario: Directory buffer replaces an open changes panel
- **WHEN** the changes panel is open beside an editor and `:edit internal` runs in the editor
- **THEN** no changes-panel or diff-view window remains and the focused project tree is rooted at `internal`

### Requirement: Project tree sidebar
The action `file_tree.toggle` SHALL open the project tree for the cwd in a left-docked window 35 columns wide with `winfixwidth`, filetype `gleb-file-tree` and a `nofile` buffer, at most one per tab page, reveal the current file, and focus it. When current it SHALL close; when open but unfocused it SHALL focus. Closing the last other non-floating window SHALL close the tree first.

#### Scenario: Project tree opens on the left at width 35
- **WHEN** the action `file_tree.toggle` runs in a tab with one file window
- **THEN** the current window has filetype `gleb-file-tree`, is the leftmost window of the tab, has width 35 and `winfixwidth` set, and the tab has two windows

#### Scenario: Project tree toggle closes a focused tree
- **WHEN** the project tree is the current window and the action `file_tree.toggle` runs
- **THEN** no window with filetype `gleb-file-tree` remains in the tab

#### Scenario: Project tree toggle focuses an open tree
- **WHEN** the project tree is open, `:wincmd l` has moved focus to the file window, and the action `file_tree.toggle` runs
- **THEN** the current window is the project tree and the tab still has two windows

#### Scenario: Project tree closes with the last window
- **WHEN** the project tree is open next to one file window and that file window is closed with `:q`
- **THEN** Neovim exits

#### Scenario: Project tree toggle reveals the current file
- **WHEN** no project tree is open, the current buffer is `internal/money/money.go` and the action `file_tree.toggle` runs
- **THEN** the current window is the project tree and its cursor is on the `money.go` row

#### Scenario: Project tree opens from non-project buffers
- **WHEN** no project tree is open and `file_tree.toggle` runs from either a file outside the cwd or a terminal buffer
- **THEN** the project tree draws its root row and top-level rows

### Requirement: Project tree and changes panel close-if-last isolation
QuitPre SHALL count project-tree and changes-panel windows as sidebars. Closing the last editor window with `:q` or `:close` SHALL close sidebars first without clearing another tab's state or autocmds. A tab containing both sidebar types SHALL still quit as if neither were present.

#### Scenario: Project tree closes before last editor with close
- **WHEN** the project tree is open next to one file window and that file window is closed with `:close`
- **THEN** the tab page closes without an error or a remaining project-tree window

#### Scenario: Project tree and changes panel close before the last editor
- **WHEN** project tree and changes panel windows are open next to one file window and that file window is closed with `:q`
- **THEN** both sidebar windows close first and Neovim exits

## MODIFIED Requirements

### Requirement: Filesystem tree toggle
The normal-mode project tree toggle SHALL reveal an existing current buffer file and SHALL focus the project tree with its cursor on the root row, without an error, when the current buffer path does not exist on disk.

#### Scenario: Toggle tolerates a deleted current file
- **WHEN** an existing file is opened, deleted from disk, and the normal-mode `<A-e>` mapping is pressed
- **THEN** no error is raised, the current window has filetype `gleb-file-tree` and its cursor is on the root row

### Requirement: Project tree editor-window hygiene
File-opening actions SHALL run from the target editor window, never the tree, and skip the changes panel, quickfix, terminal, floating and diff-view windows. If a file replaces the tree buffer, it SHALL move to an eligible editor window. New split and tab windows SHALL inherit editor options, not tree-only options.

#### Scenario: Project tree opening skips non-editor windows
- **WHEN** the changes panel, quickfix, terminal, floating and diff-view windows are present, the project tree is focused on `Makefile`, and `<CR>` is pressed in normal mode
- **THEN** `Makefile` opens in the most recently used normal editor window and none of the skipped windows is replaced

#### Scenario: A file cannot replace the project tree buffer
- **WHEN** the project tree window is current and `:edit Makefile` runs
- **THEN** `Makefile` is shown in a normal editor window and the project tree remains open in its own window

#### Scenario: Project tree split windows keep editor options
- **WHEN** `v` or `s` is pressed in normal mode on the `Makefile` row
- **THEN** the new current window shows `Makefile`, has `number` set and does not have `winfixwidth` set

#### Scenario: Project tree tab windows keep editor options
- **WHEN** `t` is pressed in normal mode on the `Makefile` row
- **THEN** the new tab's current window shows `Makefile`, has `number` set and does not have `winfixwidth` set

### Requirement: Project tree follows the current file
While the tree is open, entering a file under its root SHALL reveal it without moving focus. `file_tree.reveal` SHALL do the same and focus the tree, opening it if needed. A missing file SHALL select the root. Files outside the root and URI buffers SHALL be ignored. Entering a directory buffer SHALL leave the tree root and cursor unchanged.

#### Scenario: Project tree follows the current file
- **WHEN** the project tree is open and `:edit internal/money/money.go` runs in the file window
- **THEN** the `money` row shows U+F47C, the tree cursor is on the `money.go` row, and the current window is the file window

#### Scenario: Project tree ignores files outside the root
- **WHEN** the project tree is open with its cursor on the `go.mod` row and a file outside the root is edited in the file window
- **THEN** the tree cursor is still on the `go.mod` row and no error is raised

#### Scenario: Project tree reveal focuses the current file
- **WHEN** no project tree is open, the current buffer is `internal/money/money.go` and the action `file_tree.reveal` runs
- **THEN** the current window is the project tree and its cursor is on the `money.go` row

#### Scenario: Project tree reveal tolerates a deleted file
- **WHEN** the current buffer's file was deleted from disk and the action `file_tree.reveal` runs
- **THEN** no error is raised, the project tree is focused and its cursor is on the root row

#### Scenario: Project tree follow tolerates a deleted file
- **WHEN** the project tree is open and `BufEnter` runs for a file buffer whose file was deleted from disk
- **THEN** the tree cursor moves to the root row and no error or notification is raised

#### Scenario: Project tree toggle tolerates a deleted file
- **WHEN** no project tree is open, the current buffer's file was deleted from disk and the action `file_tree.toggle` runs
- **THEN** the project tree opens with its cursor on the root row and no error or notification is raised

#### Scenario: Project tree does not follow a directory buffer
- **WHEN** the project tree cursor is on `go.mod` and a directory buffer for `internal` is entered
- **THEN** the tree root and cursor stay unchanged on `go.mod` and no error or notification is raised

## REMOVED Requirements

### Requirement: Project tree window
**Reason**: its scenario "Project tree actions start unbound" stops holding when `<A-e>` runs `file_tree.toggle`; the rest of the requirement continues unchanged under a new name.
**Migration**: replaced by "Project tree sidebar", which keeps its six surviving scenarios verbatim; "Project tree actions start unbound" → `keymaps: Alt-e reveals current file` (the action is now bound).

### Requirement: Project tree close-if-last isolation
**Reason**: neo-tree is removed, so close-if-last isolation now coordinates the project tree with the changes panel.
**Migration**: replaced by "Project tree and changes panel close-if-last isolation": "Project tree closes before last editor with close" keeps its title; "Project and neo-tree close before the last editor" → `file-tree: Project tree and changes panel close before the last editor`.

### Requirement: Tree sources and window
**Reason**: neo-tree is removed; its two sources become owned panels.
**Migration**: "Filesystem tree opens on the left at width 35" → `file-tree: Project tree opens on the left at width 35`; "Git status tree opens on the left at width 35" → `git: Changes panel opens on the left at width 35`; "Tree closes with last window" → `file-tree: Project tree closes with the last window`; "Missing neo-tree is tolerated" → none (the tree is own code with no plugin to miss).

### Requirement: Common tree open mappings
**Reason**: neo-tree's window mappings go away with neo-tree.
**Migration**: "v opens file in vertical split" → `file-tree: Project tree v opens a vertical split`; "t opens file in new tab" → `file-tree: Project tree t opens a new tab`; "Next source switches tree source" → `keymaps: Alt-G replaces the project tree with the changes panel`; "o and l keep native open in git status tree" → `git: Changes panel Enter opens the file`.

### Requirement: Common tree edit mappings
**Reason**: neo-tree's add and rename commands go away with neo-tree.
**Migration**: "a creates a file" → `file-tree: Project tree a creates a file in the folder under the cursor`; "r renames a file" → `file-tree: Project tree r renames a file and its buffer`.

### Requirement: Filesystem source behaviour
**Reason**: the neo-tree `filesystem` source is removed.
**Migration**: "Dotfiles and gitignored files are listed" → `file-tree: Project tree lists folders first in case-insensitive order` and `file-tree: I toggles ignored entries`; "Directory argument opens tree in current window" → `file-tree: Directory argument opens the project tree`; "Current file is followed" → `file-tree: Project tree follows the current file`. The `H` hidden toggle has no successor.

### Requirement: Git status navigation previews diffs
**Reason**: the git status tree and its tab preview are replaced by the changes panel with the diff view in the editor area.
**Migration**: "j skips directories and previews next file" → `git: Changes panel j shows the next file in the diff view`; "k skips directories and previews previous file" → `git: Changes panel keeps the diff on a directory row`; "Deleted file is not previewed" → `git: Changes panel shows a deleted file`.

### Requirement: Git status open, close and staging actions
**Reason**: the git status tree is replaced by the changes panel.
**Migration**: "Enter opens file and switches to filesystem tree" → `git: Changes panel Enter opens the file` (the panel stays, IntelliJ F4); "q closes preview and tree" → `git: Changes panel q closes the panel and the diff view`; "Space stages an unstaged file" → `git: Changes panel Space stages an unstaged file`; "Space unstages a staged file" → `git: Changes panel Space unstages a staged file`.

### Requirement: Git status staging matches exact paths
**Reason**: the exact-path staging rule moves to the changes panel unchanged.
**Migration**: all six scenarios map one-for-one to the `git: Changes panel …` successors in design.md's Removed scenarios table, preserving suffix-path, outside-repository, subdirectory-cwd and failure bounds.

### Requirement: Git status revert and key ownership
**Reason**: the git status tree is replaced by the changes panel.
**Migration**: the two `X` scenarios map to the same-titled changes-panel successors; `gr` → `git: Changes panel leaves gr global`; `c` → `file-tree: Project tree c and p copy a file into another folder`.

### Requirement: Git status AI commit
**Reason**: the git status tree is replaced by the changes panel, which opens the same AI commit popup.
**Migration**: "gc commits confirmed message" → `git: Changes panel gc commits confirmed message`; "gc reports commit failure" → `git: Changes panel gc reports commit failure`; "Help lists the moved git status keys" → none (no neo-tree help popup; the keys are listed by Find Action and `:map`).

### Requirement: Git status push
**Reason**: the git status tree is replaced by the changes panel.
**Migration**: "P pushes successfully" → `git: Changes panel P pushes successfully`; "P reports push failure" → `git: Changes panel P reports push failure`.

### Requirement: Diff preview state
**Reason**: `lua/gleb/file_tree/diff_preview.lua` is removed; there is no preview tab to track.
**Migration**: "State starts empty" and "Reset clears populated state" → none (the changes panel's state is internal; its behaviour is pinned by the `git: Changes panel …` diff view scenarios).

### Requirement: Diff preview opening
**Reason**: the codediff preview tab is replaced by the diff view shown in the editor window.
**Migration**: "Nil path is ignored" → none; "Same file is ignored" and "Diff tab is reused across files" → `git: Changes panel j shows the next file in the diff view` (one reused view, tab count unchanged); "Current file is tracked immediately", "Original tab is saved" and "Diff tab is created" → none (no tab); "Rapid calls are debounced" → `git: Changes panel debounces rapid moves`.

### Requirement: Diff preview tree in diff tab
**Reason**: the preview no longer opens a second tab with its own tree.
**Migration**: "Neo-tree is opened and focused in diff tab" → `git: Changes panel j shows the next file in the diff view` (focus stays in the one panel).

### Requirement: Diff preview git errors
**Reason**: the preview module is removed.
**Migration**: "File outside a repository" → `git: Changes panel outside a repository` (same `Git root error:` text).

### Requirement: Diff preview focus and closing
**Reason**: the preview tab, its focus guard and the return to the original tab are gone: the diff view never takes focus and lives in the current tab.
**Migration**: the three focus scenarios → `git: Changes panel j shows the next file in the diff view`; the five return/state scenarios → `git: Changes panel q closes the panel and the diff view`. design.md's Removed scenarios table keeps every title.

### Requirement: Tree icons
**Reason**: the neo-tree renderer is removed.
**Migration**: the three folder-icon scenarios → `file-tree: Project tree rows have icons and no guides`; diagnostics → none; conflict symbol → `file-tree: Project tree colours renamed and conflicted files`; screenshot → `file-tree: Project tree matches the approved render`.

### Requirement: Neo-tree mapping ownership
**Reason**: neo-tree and its mapping adapter are removed.
**Migration**: "Tree mappings come from the shortcut file" → `file-tree: Project tree keys come from the keymap file` and `git: Changes panel mappings come from the shortcut file`; "Neo-tree defaults stay disabled" → none (no plugin defaults exist).
