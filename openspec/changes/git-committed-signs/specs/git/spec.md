## ADDED Requirements

### Requirement: Committed signs
In a file buffer of a repository with a branch base (`gleb.git.base`), every line changed between the merge-base and HEAD SHALL carry a sign in namespace `gleb_git_committed_signs`: the gitsigns bar for added and changed lines, and the gitsigns delete glyph for deleted ones. The signs are in `GitCommittedSign` (palette purple `#d3869b`) at priority 5, below gitsigns' 6. Without a base, no sign is drawn.

#### Scenario: Committed signs mark the branch's lines
- **WHEN** `internal/billing/invoice.go` of a fresh `prbranch` copy is edited (the `gh` stub reports no pull request)
- **THEN** within 3 s the extmarks of namespace `gleb_git_committed_signs` are exactly on the manifest's `committed` `add` and `change` lines of that file, each with sign text `┃`, `sign_hl_group` `GitCommittedSign` and priority 5, and the manifest's uncommitted `hunks` line has none

#### Scenario: Committed signs mark every line of a file added on the branch
- **WHEN** `internal/billing/tax.go` of a fresh `prbranch` copy is edited
- **THEN** within 3 s every manifest `committed` `add` line of `tax.go` carries a `GitCommittedSign` sign, and no other line does

#### Scenario: Committed signs mark deleted lines
- **WHEN** `lib/util.lua` of the design.md Decision 9 deletion repo is edited on `feat/x`
- **THEN** within 3 s the namespace holds one extmark, on line 2, whose sign text equals the gitsigns config's `delete` text

#### Scenario: Committed signs colour is gruvbox purple
- **WHEN** Neovim starts with the full config, and again after `:colorscheme gruvbox-material`
- **THEN** `GitCommittedSign` resolves to fg `#d3869b`

#### Scenario: Committed signs are absent without a base
- **WHEN** a fresh `prbranch` copy runs `git stash -q` and `git checkout -q main`, and `internal/billing/invoice.go` is edited
- **THEN** after 1 s the namespace `gleb_git_committed_signs` has no extmark in that buffer

#### Scenario: Committed signs kinds and mapping follow the unit table
- **WHEN** `require("gleb.git.committed_signs.map")` `kinds` and `to_buffer` run over the rows of design.md Decision 4
- **THEN** each row returns its committed kinds and its buffer signs, e.g. base `a b c d`, head `a B c x d`, buffer `new a B c x d` gives `{ [3] = "change", [5] = "add" }`

### Requirement: Committed signs follow the buffer
The signs SHALL be re-mapped onto the live buffer, unsaved edits included, within `DEBOUNCE_MS` after an edit. A committed line changed locally SHALL lose its sign, so gitsigns' sign shows. On `User GlebGitBaseChanged` the signs of that root SHALL be recomputed, or cleared when the base is gone. Re-mapping a 10 000-line buffer SHALL take under 50 ms.

#### Scenario: Committed signs move with unsaved edits
- **WHEN** in the edited `invoice.go` of a fresh `prbranch` copy, `ggO// one<Esc>o// two<Esc>` inserts two lines above line 1 without writing
- **THEN** within 1 s the committed signs sit on the manifest lines plus 2, and `&modified` is true

#### Scenario: Committed signs yield to a local change on the same line
- **WHEN** in the edited `invoice.go` of a fresh `prbranch` copy, the first manifest `change` line is replaced with `	Tax   Rate // per invoice` and gitsigns has refreshed
- **THEN** that line has no `gleb_git_committed_signs` extmark and a gitsigns sign, and the other committed lines keep theirs

#### Scenario: Committed signs refresh after a commit
- **WHEN** the edited `invoice.go` of a fresh `prbranch` copy shows its committed signs, and `git commit -qam wip` runs in the copy outside Neovim
- **THEN** within 3 s the manifest's `hunks` line of `invoice.go` also carries a `GitCommittedSign` sign

#### Scenario: Committed signs clear when HEAD is detached
- **WHEN** the edited `invoice.go` of a fresh `prbranch` copy shows its committed signs, and `git checkout -q --detach` runs in the copy outside Neovim
- **THEN** within 3 s the namespace has no extmark in that buffer

#### Scenario: Committed signs map a large buffer quickly
- **WHEN** `kinds` and `to_buffer` run on 10 000 generated lines with one committed change and one inserted buffer line
- **THEN** both together finish in under 50 ms times `H.load_factor()`, and the change maps to its line plus 1

### Requirement: Committed signs limits
Only files changed between the merge-base and HEAD SHALL be read. A file renamed on the branch SHALL be compared with its merge-base path. A binary file, a file over `MAX_BYTES` or a file over `MAX_LINES` lines SHALL get no committed signs.

#### Scenario: Committed signs skip files the branch did not change
- **WHEN** `internal/money/money.go` and a new untracked `notes.md` of a fresh `prbranch` copy are edited
- **THEN** after 1 s neither buffer has a `gleb_git_committed_signs` extmark, and no `git cat-file` ran for them

#### Scenario: Committed signs compare a renamed file with its old path
- **WHEN** `lib/helpers.lua` of the design.md Decision 9 rename repo is edited on `feat/x`
- **THEN** within 3 s only line 2 carries a committed sign

#### Scenario: Committed signs skip a file over the line limit
- **WHEN** `require("gleb.git.committed_signs").MAX_LINES` is set to 10 and `internal/billing/tax.go` (11 lines) of a fresh `prbranch` copy is edited
- **THEN** after 1 s the buffer has no `gleb_git_committed_signs` extmark

### Requirement: Committed signs screen
The editor gutter on a branch SHALL match the approved purple render.

#### Scenario: Committed signs match the approved render
- **WHEN** a `100x30` screen edits `internal/billing/invoice.go` of a fresh `prbranch` copy with gopls, null-ls and diagnostics off, and the gitsigns hunk and the committed signs are drawn, with the cursor on line 1
- **THEN** the screen matches the reference screenshot of design.md "Proposed — committed signs", and columns 1-6 of screen rows 2-29 match its colour mask
