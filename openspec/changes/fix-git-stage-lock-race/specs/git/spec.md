# Spec Delta

## MODIFIED Requirements

### Requirement: Changes panel rows
The panel SHALL disable optional Git locks for its non-mutating status and line-stat refresh reads. It SHALL run `git --no-optional-locks status --porcelain=v2 -z --untracked-files=all` in the root and consume shared status records in one grouping pass. It SHALL draw `Changes <n> files` and an optional `Unversioned Files <n> files`, group by compacted directories, sort directories before files by name, and cap rows at the project tree's row limit.

#### Scenario: Changes panel lists the dirty fixture
- **WHEN** the changes panel is opened on a fresh copy of the `dirty` fixture
- **THEN** the panel rows, with icons and padding removed, are in order `Changes 4 files`, `lib 1`, `c.lua +1 -1`, `a.txt +1 -0`, `b.txt +2 -2`, `d.txt +2 -2`, `Unversioned Files 1 file`, `new.txt`

#### Scenario: Changes panel compacts single-child directories
- **WHEN** the changes panel is opened on a fresh copy of the `billing` fixture
- **THEN** the directory rows read `internal/billing 4` and `web/src 1`, and no row reads `internal`, `billing`, `web` or `src` alone

#### Scenario: Changes panel hides an empty Unversioned Files root
- **WHEN** the changes panel is opened on a repository whose only change is a modified tracked file `a.txt`
- **THEN** the rows are `Changes 1 file` and `a.txt +1 -1`, and no row starts with `Unversioned Files`

#### Scenario: Changes panel keeps one path in both roots
- **WHEN** a repository reports the same path with a tracked worktree change and as an untracked path and the Changes panel opens
- **THEN** one row for that path is under `Changes` and a second row is under `Unversioned Files`

#### Scenario: Changes panel lists directory and submodule records
- **WHEN** porcelain status reports an untracked `vendor/` directory record and a tracked submodule whose sub field starts with `S`
- **THEN** each is a file row, selecting either opens no diff, `<CR>` opens no file, and an INFO notification explains that the row has no file content

#### Scenario: Changes panel status avoids optional locks
- **WHEN** the Changes panel refreshes in a repository
- **THEN** its status command starts with `git --no-optional-locks status --porcelain=v2 -z --untracked-files=all`

#### Scenario: Changes panel refresh reads avoid optional locks
- **WHEN** the Changes panel refreshes in a repository
- **THEN** the status and line-stat processes run with `GIT_OPTIONAL_LOCKS=0`

#### Scenario: Changes panel caps rows
- **WHEN** grouping status records would produce more rows than the project tree row limit
- **THEN** the Changes panel stops at that limit and notifies that the row limit was reached
