## ADDED Requirements

### Requirement: Git status staging matches exact paths
In the `git_status` tree, `<space>` on a file node SHALL treat the file as staged only if git reports staged changes for the exact pathspec of its absolute path (`git diff --cached --quiet -- <path>` run in the tree root), independent of the current working directory. It SHALL run `git add` or `git reset` with an argument list (no shell) and, on a non-zero exit, notify `Stage failed: <stderr>` or `Unstage failed: <stderr>` at ERROR.

#### Scenario: Space stages a file whose name is a suffix of a staged file
- **WHEN** `aa.lua` is staged, `a.lua` is modified and unstaged, the cursor is on the `a.lua` file node and `<space>` is pressed in normal mode
- **THEN** both `a.lua` and `aa.lua` appear in `git diff --cached --name-only`

#### Scenario: Space stages when cwd is outside the repository
- **WHEN** the cwd is a directory outside the repository, the tree was opened with `:Neotree git_status dir=<repo>`, `a.lua` is modified and unstaged, the cursor is on its file node and `<space>` is pressed in normal mode
- **THEN** `a.lua` appears in `git diff --cached --name-only` run in the repository

#### Scenario: Space unstages when cwd is outside the repository
- **WHEN** the cwd is a directory outside the repository, the tree was opened with `:Neotree git_status dir=<repo>`, `a.lua` is staged, the cursor is on its file node and `<space>` is pressed in normal mode
- **THEN** `a.lua` no longer appears in `git diff --cached --name-only` run in the repository

#### Scenario: Space reports a staging failure
- **WHEN** `.git/index.lock` exists, the cursor is on an unstaged file node and `<space>` is pressed in normal mode
- **THEN** a notification starting with `Stage failed:` at ERROR is emitted
