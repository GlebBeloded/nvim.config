## MODIFIED Requirements

### Requirement: File tree and git panel toggles
The config SHALL map `<A-e>` in normal mode to a smart neo-tree toggle for the `filesystem` source and `<A-G>` to the same toggle for the `git_status` source. When the current window is neo-tree, the toggle SHALL close it if it shows the requested source and otherwise switch it to that source. When the current window is not neo-tree, the toggle SHALL focus neo-tree on the requested source, revealing the current file for `filesystem` only when the buffer names an existing file on disk.

#### Scenario: Alt-e reveals current file
- **WHEN** a file `foo.lua` is being edited and `<A-e>` is pressed in normal mode
- **THEN** the current window has `filetype` `neo-tree`, its buffer name contains `neo-tree filesystem`, and the cursor line refers to `foo.lua`

#### Scenario: Alt-e on URI buffer focuses filesystem
- **WHEN** the current buffer is named `vscodediff://x` and `<A-e>` is pressed in normal mode
- **THEN** the current window is a neo-tree `filesystem` window and no error is reported

#### Scenario: Alt-e tolerates a deleted current file
- **WHEN** an existing file is opened, deleted from disk, and the normal-mode `<A-e>` mapping is pressed
- **THEN** no error is raised and the focused tree uses the `filesystem` source without trying to reveal the deleted path

#### Scenario: Alt-e closes focused filesystem tree
- **WHEN** the current window is the neo-tree `filesystem` window and `<A-e>` is pressed in normal mode
- **THEN** no window with `filetype` `neo-tree` remains

#### Scenario: Alt-G switches tree to git status
- **WHEN** the current window is the neo-tree `filesystem` window and `<A-G>` is pressed in normal mode
- **THEN** the current window is a neo-tree window whose buffer name contains `neo-tree git_status`

#### Scenario: Alt-G closes focused git status tree
- **WHEN** the current window is the neo-tree `git_status` window and `<A-G>` is pressed in normal mode
- **THEN** no window with `filetype` `neo-tree` remains
