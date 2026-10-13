# Spec Delta

## MODIFIED Requirements

### Requirement: Gitlink permalink command
The config SHALL configure gitlinker with no default mappings, without printing the URL, and with host `pgw.dev` producing GitHub-style URLs. It SHALL define the `:Gitlink` command accepting a range: without a range it copies the URL for the current line, with a range it copies the URL for the inclusive line endpoints supplied to the command; the URL SHALL be copied to the `+` register. After a ranged command, including one that fails, it SHALL restore the cursor and visual selection marks, leave Normal mode, and propagate any failure.

#### Scenario: Gitlink copies current line URL
- **WHEN** `:Gitlink` is executed in a tracked file of a repository with a GitHub remote, cursor on line 10
- **THEN** register `+` contains a blob URL for the current commit and file ending in `#L10`

#### Scenario: Gitlink copies range URL
- **WHEN** lines 3-5 are selected in visual mode and `:'<,'>Gitlink` is executed
- **THEN** register `+` contains a blob URL ending in `#L3-L5`
- **THEN** Normal mode is active and the cursor is restored to its pre-command position

#### Scenario: Gitlink range preserves editor state
- **WHEN** `:3,5Gitlink` is executed from Normal mode after a different visual selection was made
- **THEN** Normal mode is active and the cursor and `'<`/`'>` marks retain their pre-command positions

#### Scenario: Gitlink range failure restores editor state
- **WHEN** `:3,5Gitlink` fails while generating a permalink from Normal mode
- **THEN** Normal mode is active and the cursor and `'<`/`'>` marks retain their pre-command positions
- **THEN** the command reports the original failure

#### Scenario: pgw.dev remote uses GitHub URL format
- **WHEN** `:Gitlink` is executed in a repository whose `origin` remote is on host `pgw.dev`
- **THEN** register `+` contains a URL of the form `https://pgw.dev/<owner>/<repo>/blob/<sha>/<path>#L<n>`
