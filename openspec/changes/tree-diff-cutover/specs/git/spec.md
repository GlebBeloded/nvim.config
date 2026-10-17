## ADDED Requirements

### Requirement: Changes review workflow
In a repository with staged, unstaged and untracked changes, Cmd+G SHALL open the changes panel with the diff view of the selected file, and in a diff window `]f` SHALL show the panel's next changed file and `]c` SHALL move the cursor to the next change of the current file.

#### Scenario: Cmd+G opens the changes review of a dirty repo
- **WHEN** Neovim runs in a fresh copy of the `dirty` fixture and Cmd+G is pressed as a real key press
- **THEN** the changes panel is the leftmost window of the current tab and lists exactly the fixture manifest's changed files: `a.txt` (staged), `b.txt` and `lib/c.lua` (unstaged), `d.txt` (staged and unstaged) and `new.txt` (untracked), and the editor area shows the diff view of `lib/c.lua`

#### Scenario: ]f steps to the next changed file in the changes review
- **WHEN** the changes review shows a changed file of the `dirty` fixture with a diff window focused and `]` `f` is pressed as a real key press
- **THEN** the diff view shows the next file in the panel's order, and repeating `]` `f` visits every changed file of the manifest once

#### Scenario: ]c steps to the next change in the changes review
- **WHEN** the changes review shows `b.txt` of the `dirty` fixture with the cursor of the right diff window in its first change and `]` `c` is pressed as a real key press
- **THEN** the cursor is on the first changed line of the second hunk from the manifest

### Requirement: Diffview mapping ownership
Diffview SHALL disable its default mappings and derive configured window mappings from registered git actions and current `settings/keymap.json` assignments. Diffview's spec-retained `<leader>co`, `<leader>ct`, `<leader>cb`, and `<leader>ca` conflict choices SHALL be registered as view-scoped `conflict_choose` actions with those current assignments. Opening a viewer after reassignment SHALL use only the new lhs.

#### Scenario: Diffview mappings come from git actions
- **WHEN** diffview opens a populated view and file panel after `VeryLazy`
- **THEN** every configured mapping invokes the git action assigned by `settings/keymap.json` and an unconfigured diffview default is absent

#### Scenario: Diffview conflict choices come from git actions
- **WHEN** diffview opens a populated conflict view after `VeryLazy`
- **THEN** `<leader>co`, `<leader>ct`, `<leader>cb`, and `<leader>ca` invoke the registered `diffview.choose_ours`, `diffview.choose_theirs`, `diffview.choose_base`, and `diffview.choose_all` actions assigned by `settings/keymap.json`

## MODIFIED Requirements

### Requirement: Module loading
`require("gleb.git")` SHALL load, in order, the gitsigns, diffview and gitlink configurations and the changes panel. The gitsigns and diffview configurations SHALL return without error when their plugin cannot be required. differ.nvim and vscode-diff.nvim SHALL not be installed.

#### Scenario: Missing optional git plugins are tolerated
- **WHEN** `require("gleb.git.gitsigns")` and `require("gleb.git.diffview")` are called with those plugins absent from the runtimepath
- **THEN** no error is raised

#### Scenario: Git commands are available after startup
- **WHEN** Neovim starts with the full config
- **THEN** user commands `Gitsigns`, `DiffviewOpen` and `Gitlink` exist (`vim.fn.exists(":<cmd>") == 2`), and `Differ`, `CodeDiff` and `VscodeDiff` do not

#### Scenario: Removed diff plugins are not registered
- **WHEN** the lazy.nvim plugin list and `lazy-lock.json` are read after startup
- **THEN** neither names `differ.nvim`, `vscode-diff.nvim` or `neo-tree.nvim`, and `diffview.nvim`, `gitsigns.nvim` and `nui.nvim` are still listed

## REMOVED Requirements

### Requirement: Differ viewer
**Reason**: differ.nvim is removed; the changes panel with the diff view replaces its panel and diff.
**Migration**: "Differ opens panel on the left" → `git: Changes panel opens on the left at width 35`.

### Requirement: vscode-diff configuration
**Reason**: vscode-diff.nvim (codediff) is removed; the diff view (`diff` capability) replaces it.
**Migration**: "vscode-diff setup runs on plugin load" → none (no plugin to configure; the diff view is own code).

### Requirement: Differ review workflow
**Reason**: Cmd+G opens the changes review instead of differ.
**Migration**: "Cmd+G opens differ listing every change of a dirty repo" → `git: Cmd+G opens the changes review of a dirty repo`; "]f steps to the next changed file in differ" → `git: ]f steps to the next changed file in the changes review`; "]c steps to the next hunk in differ" → `git: ]c steps to the next change in the changes review` (differ's `hunk 2/2` winbar has no successor).

### Requirement: Git plugin mapping ownership
**Reason**: differ and codediff are removed, so only diffview's mappings remain to own.
**Migration**: replaced by "Diffview mapping ownership": "Diffview mappings come from git actions" and "Diffview conflict choices come from git actions" keep their titles there; "Differ mappings come from git actions" and "Codediff mappings come from git actions" → none (no such viewers; the diff view's keys are pinned by the `diff` capability).
