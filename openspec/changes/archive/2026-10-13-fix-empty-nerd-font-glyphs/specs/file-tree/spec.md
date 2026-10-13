## ADDED Requirements

### Requirement: Tree icons
The tree SHALL draw a Nerd Font glyph in every icon slot: expanders U+F460 (collapsed) and U+F47C (expanded); folder icons U+E5FF (closed), U+E5FE (open) and U+F0256 (empty); the git conflict symbol U+E727; and, for a file with diagnostics, the diagnostic sign glyph of its most severe diagnostic (the same glyphs as the `lsp` sign column). No icon slot SHALL be drawn as a blank cell.

#### Scenario: Collapsed directory shows expander and folder icon
- **WHEN** `:Neotree filesystem` is executed in a directory containing the subdirectory `docs`
- **THEN** the tree row of `docs` shows U+F460, then U+E5FF, then `docs`

#### Scenario: Expanded directory shows open expander and folder icon
- **WHEN** the cursor is on the `docs` row of the `filesystem` tree and `<cr>` is pressed in normal mode
- **THEN** the tree row of `docs` shows U+F47C, then U+E5FE, then `docs`

#### Scenario: Empty directory shows empty folder icon
- **WHEN** the cursor is on the row of a subdirectory `empty` that has no entries and `<cr>` is pressed twice in normal mode (expand, then collapse)
- **THEN** the tree row of `empty` shows U+F0256 before `empty`

#### Scenario: Tree shows diagnostic glyph of a file
- **WHEN** `:Neotree filesystem` shows file `sample.lua`, the buffer of `sample.lua` gets one error via `vim.diagnostic.set`, and the tree refreshes
- **THEN** the tree row of `sample.lua` contains U+F057

#### Scenario: Conflicted file shows conflict symbol
- **WHEN** `:Neotree git_status` is executed in a git repository where `conflict.txt` is unmerged after a failed `git merge`
- **THEN** the tree row of `conflict.txt` contains U+E727

#### Scenario: filesystem tree matches reference screenshot
- **WHEN** `:Neotree filesystem` is executed in a fixture directory with subdirectories `docs` (containing `workflow.md`), `empty` (no entries) and `lua` (containing `gleb/`) and file `init.lua`, `<cr>` is pressed on `docs` and twice on `empty`, and a screenshot of the tree rows below the root row is taken
- **THEN** it matches the stored reference screenshot, with an expander and a folder glyph on every directory row
