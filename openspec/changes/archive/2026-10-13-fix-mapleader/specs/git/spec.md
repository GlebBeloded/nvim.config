## MODIFIED Requirements

### Requirement: Diffview view mappings
In diffview diff windows the config SHALL map, in normal mode, `<tab>`/`<s-tab>` to next/previous entry, `gf` to edit the file, `<D-o>` (Cmd+O), `<D-i>` (Cmd+I), `<D-d>` (Cmd+D), `<D-a>` (Cmd+A) to choose ours/theirs/base/all conflict versions and `dx` to choose none.

#### Scenario: tab moves to next entry
- **WHEN** `:DiffviewOpen` shows two changed files, focus is in a diff window of the first, and `<tab>` is pressed in normal mode
- **THEN** the diff windows show the second file

#### Scenario: dx drops both conflict sides
- **WHEN** `:DiffviewOpen` is open on a file with a merge conflict, the cursor is inside a conflict in a diff window, and `dx` is pressed in normal mode
- **THEN** the conflict markers and both sides are removed from the working-file buffer

#### Scenario: Cmd+O chooses ours
- **WHEN** `:DiffviewOpen` is open on a file with a diff3 merge conflict (ours `ours`, base `base`, theirs `theirs`), the cursor is inside the conflict in a diff window, and `<D-o>` is pressed in normal mode
- **THEN** the working-file buffer holds `ours` in place of the conflict and no conflict marker remains

#### Scenario: Cmd+I chooses theirs
- **WHEN** `:DiffviewOpen` is open on a file with a diff3 merge conflict (ours `ours`, base `base`, theirs `theirs`), the cursor is inside the conflict in a diff window, and `<D-i>` is pressed in normal mode
- **THEN** the working-file buffer holds `theirs` in place of the conflict and no conflict marker remains

#### Scenario: Cmd+D chooses base
- **WHEN** `:DiffviewOpen` is open on a file with a diff3 merge conflict (ours `ours`, base `base`, theirs `theirs`), the cursor is inside the conflict in a diff window, and `<D-d>` is pressed in normal mode
- **THEN** the working-file buffer holds `base` in place of the conflict and no conflict marker remains

#### Scenario: Cmd+A chooses all
- **WHEN** `:DiffviewOpen` is open on a file with a diff3 merge conflict (ours `ours`, base `base`, theirs `theirs`), the cursor is inside the conflict in a diff window, and `<D-a>` is pressed in normal mode
- **THEN** the working-file buffer holds `ours`, `base`, `theirs` in that order in place of the conflict and no conflict marker remains
