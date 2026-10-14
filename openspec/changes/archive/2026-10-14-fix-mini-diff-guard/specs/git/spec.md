## MODIFIED Requirements

### Requirement: Gutter signs
The config SHALL show git hunk signs in the sign column using `┃` for added, untracked, changed and changed-deleted lines and `` for deleted and top-deleted lines, with number highlighting, line highlighting, word diff and current-line blame disabled by default. No other plugin SHALL draw hunk signs over them.

#### Scenario: Added line shows bar sign
- **WHEN** a tracked file is edited to add a new line and gitsigns has refreshed the buffer
- **THEN** the sign column on that line shows `┃`

#### Scenario: Added line has no competing hunk sign
- **WHEN** a tracked file is edited to add a new line and gitsigns has refreshed the buffer
- **THEN** gitsigns is the only configured hunk-sign source on that line, and `mini.diff` is neither loaded nor registered with lazy.nvim

#### Scenario: Blame is off by default
- **WHEN** a tracked file is opened and the cursor rests on a line for more than 300 ms
- **THEN** no blame virtual text is shown at end of line

#### Scenario: Added line sign matches reference screenshot
- **WHEN** Neovim starts with the full config at 60x8 and `:edit sample.lua` opens a committed file in a temp git repo whose working copy adds `M.x = 1` as line 2, and gitsigns has refreshed the buffer
- **THEN** screen rows 2-5 match the reference screenshot of design.md "Proposed": the sign column of line 2 draws `┃` in [GitSignsAdd] and no other line has a sign
