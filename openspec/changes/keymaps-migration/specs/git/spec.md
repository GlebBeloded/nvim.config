# git Specification

## ADDED Requirements

### Requirement: Git plugin mapping ownership
Differ, diffview, and codediff SHALL disable their default mappings and derive configured window mappings from registered git actions and current `settings/keymap.json` assignments. Opening a viewer after reassignment SHALL use only the new lhs.

#### Scenario: Diffview mappings come from git actions
- **WHEN** diffview opens a populated view and file panel after `VeryLazy`
- **THEN** every configured mapping invokes the git action assigned by `settings/keymap.json` and an unconfigured diffview default is absent

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

