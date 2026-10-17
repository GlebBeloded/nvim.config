## ADDED Requirements

### Requirement: Project tree opens for a directory buffer
Editing a directory SHALL open the project tree rooted at that directory as the left sidebar and focus it, and SHALL replace the directory buffer in its window with an empty buffer. netrw SHALL not load.

#### Scenario: Directory argument opens the project tree
- **WHEN** `:edit <dir>` runs for a directory `docs` that contains `workflow.md`
- **THEN** the current window has filetype `gleb-file-tree`, its root row names `docs` and a `workflow.md` row follows, no window shows a buffer named `<dir>`, and no buffer has filetype `netrw`

#### Scenario: netrw is not loaded
- **WHEN** Neovim starts with the full config and `VeryLazy` has fired
- **THEN** `:Explore` is not a command (`vim.fn.exists(":Explore") == 0`) and `lazy.nvim`'s `performance.rtp.disabled_plugins` contains `netrwPlugin`

### Requirement: Project tree sidebar
The action `file_tree.toggle` SHALL open the project tree for the cwd in a left-docked window 35 columns wide with `winfixwidth`, filetype `gleb-file-tree` and a `nofile` buffer, at most one per tab page, and focus it. When the tree is the current window it SHALL close it. When the tree is open but not focused it SHALL focus it. Closing the last other non-floating window SHALL close the tree first, so `:q` behaves as without a tree.

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

## MODIFIED Requirements

### Requirement: Filesystem tree toggle
The normal-mode project tree toggle SHALL reveal an existing current buffer file and SHALL focus the project tree with its cursor on the root row, without an error, when the current buffer path does not exist on disk.

#### Scenario: Toggle tolerates a deleted current file
- **WHEN** an existing file is opened, deleted from disk, and the normal-mode `<A-e>` mapping is pressed
- **THEN** no error is raised, the current window has filetype `gleb-file-tree` and its cursor is on the root row

## REMOVED Requirements

### Requirement: Project tree window
**Reason**: its scenario "Project tree actions start unbound" stops holding when `<A-e>` runs `file_tree.toggle`; the rest of the requirement continues unchanged under a new name.
**Migration**: replaced by "Project tree sidebar", which keeps "Project tree opens on the left at width 35", "Project tree toggle closes a focused tree", "Project tree toggle focuses an open tree" and "Project tree closes with the last window" verbatim; "Project tree actions start unbound" → `keymaps: Alt-e reveals current file` (the action is now bound).

### Requirement: Tree sources and window
**Reason**: neo-tree is removed; its `filesystem` and `git_status` sources become two panels of our own.
**Migration**: "Filesystem tree opens on the left at width 35" → `file-tree: Project tree opens on the left at width 35`; "Git status tree opens on the left at width 35" → `git: Changes panel opens on the left at width 35`; "Tree closes with last window" → `file-tree: Project tree closes with the last window`; "Missing neo-tree is tolerated" → none (the tree is own code with no plugin to miss).

### Requirement: Common tree open mappings
**Reason**: neo-tree's window mappings go away with neo-tree.
**Migration**: "v opens file in vertical split" → `file-tree: Project tree v opens a vertical split`; "t opens file in new tab" → `file-tree: Project tree t opens a new tab`; "Next source switches tree source" → none (the two panels have their own keys: Alt+E and Alt+Shift+G, `keymaps: Alt-G replaces the project tree with the changes panel`); "o and l keep native open in git status tree" → none (there is no git status source; the changes panel opens with Enter, `git: Changes panel Enter opens the file`).

### Requirement: Common tree edit mappings
**Reason**: neo-tree's add and rename commands go away with neo-tree.
**Migration**: "a creates a file" → `file-tree: Project tree a creates a file in the folder under the cursor`; "r renames a file" → `file-tree: Project tree r renames a file and its buffer`.

### Requirement: Filesystem source behaviour
**Reason**: the neo-tree `filesystem` source is removed.
**Migration**: "Dotfiles and gitignored files are listed" → `file-tree: Project tree lists folders first in case-insensitive order` (dotfiles listed) and `file-tree: I toggles ignored entries` (ignored files hidden until Show Ignored, a user decision); "Directory argument opens tree in current window" → `file-tree: Directory argument opens the project tree` (as a sidebar, not in the current window); "Current file is followed" → `file-tree: Project tree follows the current file`. The `H` hidden toggle has no successor.

### Requirement: Git status navigation previews diffs
**Reason**: the git status tree and its tab preview are replaced by the changes panel with the diff view in the editor area.
**Migration**: "j skips directories and previews next file" → `git: Changes panel j shows the next file in the diff view`; "k skips directories and previews previous file" → `git: Changes panel keeps the diff on a directory row` (folders are rows the cursor may rest on, as in IntelliJ); "Deleted file is not previewed" → `git: Changes panel shows a deleted file` (deleted files now show their `HEAD` text).

### Requirement: Git status open, close and staging actions
**Reason**: the git status tree is replaced by the changes panel.
**Migration**: "Enter opens file and switches to filesystem tree" → `git: Changes panel Enter opens the file` (the panel stays, IntelliJ F4); "q closes preview and tree" → `git: Changes panel q closes the panel and the diff view`; "Space stages an unstaged file" → `git: Changes panel Space stages an unstaged file`; "Space unstages a staged file" → `git: Changes panel Space unstages a staged file`.

### Requirement: Git status staging matches exact paths
**Reason**: the exact-path staging rule moves to the changes panel unchanged.
**Migration**: "Space stages a file whose name is a suffix of a staged file" → `git: Changes panel Space stages a file whose name is a suffix of a staged file`; "Space stages when cwd is outside the repository" → `git: Changes panel stages when cwd is outside the repository`; "Space unstages when cwd is outside the repository" → `git: Changes panel unstages when cwd is outside the repository`; "Space stages from a subdirectory cwd" → `git: Changes panel stages from a subdirectory cwd`; "Space unstages from a subdirectory cwd" → `git: Changes panel unstages from a subdirectory cwd`; "Space reports a staging failure" → `git: Changes panel reports a staging failure`.

### Requirement: Git status revert and key ownership
**Reason**: the git status tree is replaced by the changes panel.
**Migration**: "X reverts a file after confirmation" → `git: Changes panel X reverts a file after confirmation`; "X keeps a file when revert is declined" → `git: Changes panel X keeps a file when revert is declined`; "gr keeps its global meaning in git status tree" → `git: Changes panel leaves gr global`; "c is copy in git status tree" → `file-tree: Project tree c and p copy a file into another folder` (the changes panel has no file operations).

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
**Migration**: "Focus returns false without neo-tree", "Focus moves to neo-tree" and "Focus guard pulls focus back during navigation" → `git: Changes panel j shows the next file in the diff view` (the panel stays current); "Return to original tab", "Return clears current file", "Return clears tab state and focus guard", "Next preview records the new original tab" and "Return cancels a pending preview" → `git: Changes panel q closes the panel and the diff view` (no tab to return to).

### Requirement: Tree icons
**Reason**: the neo-tree renderer is removed.
**Migration**: "Collapsed directory shows expander and folder icon", "Expanded directory shows open expander and folder icon" and "Empty directory shows empty folder icon" → `file-tree: Project tree rows have icons and no guides`; "Tree shows diagnostic glyph of a file" → none (diagnostics in the tree are out of scope of `file-tree-view`); "Conflicted file shows conflict symbol" → `file-tree: Project tree colours renamed and conflicted files` (colour, no symbol: user decision "git status = name colour only"); "filesystem tree matches reference screenshot" → `file-tree: Project tree matches the approved render`.

### Requirement: Neo-tree mapping ownership
**Reason**: neo-tree and its mapping adapter are removed.
**Migration**: "Tree mappings come from the shortcut file" → `file-tree: Project tree keys come from the keymap file` and `git: Changes panel mappings come from the shortcut file`; "Neo-tree defaults stay disabled" → none (no plugin defaults exist).
