# git Specification

## ADDED Requirements

### Requirement: Git plugin mapping ownership
Differ, diffview, and codediff SHALL disable their default mappings and derive configured window mappings from registered git actions and current `settings/keymap.json` assignments. Diffview's spec-retained `<leader>co`, `<leader>ct`, `<leader>cb`, and `<leader>ca` conflict choices SHALL be registered as view-scoped `conflict_choose` actions with those current assignments. Opening a viewer after reassignment SHALL use only the new lhs.

#### Scenario: Diffview mappings come from git actions
- **WHEN** diffview opens a populated view and file panel after `VeryLazy`
- **THEN** every configured mapping invokes the git action assigned by `settings/keymap.json` and an unconfigured diffview default is absent

#### Scenario: Diffview conflict choices come from git actions
- **WHEN** diffview opens a populated conflict view after `VeryLazy`
- **THEN** `<leader>co`, `<leader>ct`, `<leader>cb`, and `<leader>ca` invoke the registered `diffview.choose_ours`, `diffview.choose_theirs`, `diffview.choose_base`, and `diffview.choose_all` actions assigned by `settings/keymap.json`

#### Scenario: Differ mappings come from git actions
- **WHEN** differ opens a populated dirty-repository review after `VeryLazy`
- **THEN** every configured mapping invokes the git action assigned by `settings/keymap.json` and an unconfigured differ default is absent

#### Scenario: Codediff mappings come from git actions
- **WHEN** codediff opens a populated diff after `VeryLazy`
- **THEN** every configured mapping invokes the git action assigned by `settings/keymap.json` and an unconfigured codediff default is absent

### Requirement: Git popup mapping ownership
The AI commit popup SHALL install its buffer-local `<CR>` and `q` mappings from registered git actions and their `settings/keymap.json` assignments while preserving the existing confirm, validation, cleanup, and discard behavior.

#### Scenario: Commit popup mappings come from git actions
- **WHEN** an AI commit popup is opened with a generated message
- **THEN** its buffer-local confirm and discard lhs values invoke the assigned registered git actions

#### Scenario: Popup confirm action ignores the placeholder
- **WHEN** an AI commit popup shows the `# No staged changes` placeholder and its configured confirm lhs is pressed in normal mode
- **THEN** the popup stays open and `on_commit` is not called

## MODIFIED Requirements

### Requirement: Diffview file panel mappings
In the diffview file panel, normal-mode `j`/`<Tab>` SHALL select and display the next entry, `k`/`<S-Tab>` the previous entry, `<CR>`/`o`/`l` the current entry, `h` close a fold, `s` toggle staging, `S` stage all, `U` unstage all, `R` refresh, and `q` run `:DiffviewClose`.

#### Scenario: j selects next entry from file panel
- **WHEN** `:DiffviewOpen` shows changed files `a.txt` and `b.txt`, focus is on `a.txt` in the file panel, and `j` is pressed in normal mode
- **THEN** `b.txt` becomes the selected entry and its diff is displayed

#### Scenario: k selects previous entry from file panel
- **WHEN** `:DiffviewOpen` shows changed files `a.txt` and `b.txt`, focus is on `b.txt` in the file panel, and `k` is pressed in normal mode
- **THEN** `a.txt` becomes the selected entry and its diff is displayed

#### Scenario: q closes diffview from file panel
- **WHEN** `:DiffviewOpen` is open, focus is in the file panel, and `q` is pressed in normal mode
- **THEN** the diffview tab is closed and the tab page count returns to its previous value

#### Scenario: s stages entry from file panel
- **WHEN** the cursor is on an unstaged file entry in the diffview file panel and `s` is pressed in normal mode
- **THEN** the file appears in `git diff --cached --name-only`

### Requirement: vscode-diff configuration
When vscode-diff loads, the config SHALL call its setup with the explorer left, 35 columns wide, in tree view mode, with every plugin default diff keymap disabled so registered actions are the sole configured mappings.

#### Scenario: vscode-diff setup runs on plugin load
- **WHEN** lazy.nvim loads `vscode-diff.nvim`
- **THEN** `require("gleb.git.vscode_diff")` executes without error and disables every default keymap
