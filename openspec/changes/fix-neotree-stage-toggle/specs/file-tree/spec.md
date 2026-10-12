## ADDED Requirements

### Requirement: Git status staging matches exact paths
In the `git_status` tree, `<space>` on a file node SHALL treat the file as staged only if its path relative to the git root is exactly one of the lines of `git diff --cached --name-only`, independent of the current working directory. It SHALL run `git add` or `git reset` with an argument list (no shell) and, on a non-zero exit, notify `Stage failed: <stderr>` or `Unstage failed: <stderr>` at ERROR.

#### Scenario: Space stages a file whose name is a suffix of a staged file
- **WHEN** `aa.lua` is staged, `a.lua` is modified and unstaged, the cursor is on the `a.lua` file node and `<space>` is pressed in normal mode
- **THEN** both `a.lua` and `aa.lua` appear in `git diff --cached --name-only`

#### Scenario: Space stages from a subdirectory cwd
- **WHEN** the cwd is the subdirectory `sub` of the repository, `sub/x.lua` is modified and unstaged, the cursor is on its file node and `<space>` is pressed in normal mode
- **THEN** `sub/x.lua` appears in `git diff --cached --name-only`

#### Scenario: Space unstages from a subdirectory cwd
- **WHEN** the cwd is the subdirectory `sub` of the repository, `sub/x.lua` is staged, the cursor is on its file node and `<space>` is pressed in normal mode
- **THEN** `sub/x.lua` no longer appears in `git diff --cached --name-only`

#### Scenario: Space reports a staging failure
- **WHEN** `.git/index.lock` exists, the cursor is on an unstaged file node and `<space>` is pressed in normal mode
- **THEN** a notification starting with `Stage failed:` at ERROR is emitted
