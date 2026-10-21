## 1. Remove the Changes-panel commit URL action
Scenarios: `git: Tab actions are in the catalog`, `git: Show Branch Commits opens the commit view`, `git: Show Branch on the default branch`, `git: Copy Commit URL is offered for a commit row`, `git: Copy Commit URL is absent away from commit rows`
- [x] 1.1 Restate `git: Copy Commit URL is offered for a commit row` and keep `git: Copy Commit URL is absent away from commit rows` in `tests/integration/git/test_changes_commit_url.lua`, driving `<M-A>` from the populated Branch contexts, and tighten `git: Tab actions are in the catalog` in `tests/integration/git/test_changes_tabs.lua`; run `make test FILE=tests/integration/git/test_changes_commit_url.lua CASE="Copy Commit URL is offered for a commit row"` and see the catalog/picker absence assertion fail
- [x] 1.2 Remove `changes.copy_commit_url` and its runner from `lua/gleb/git/changes/actions.lua` and `lua/gleb/git/changes/init.lua`; remove the obsolete positive commit-URL cases while preserving `tests/integration/git/test_changes_commit_url.lua`
- [x] 1.3 Run `make test FILE=tests/integration/git/test_changes_commit_url.lua` and `make test FILE=tests/integration/git/test_changes_tabs.lua` and see all five scenarios pass

## 2. Register the file URL action in every file-buffer context
Scenarios: `git: Copy File URL remains listed with and without a shortcut`
- [x] 2.1 Write `git: Copy File URL remains listed with and without a shortcut` in `tests/integration/git/test_file_url.lua`, opening the real picker with `<M-A>` from normal and visual modes before and after assigning a shortcut, and run `make test FILE=tests/integration/git/test_file_url.lua CASE="Copy File URL remains listed with and without a shortcut"` to see it fail
- [x] 2.2 Add the unbound `git.copy_file_url` action to `lua/gleb/git/actions.lua` with normal and visual modes and no filetype restriction
- [x] 2.3 Run `make test FILE=tests/integration/git/test_file_url.lua CASE="Copy File URL remains listed with and without a shortcut"` and see it pass

## 3. Copy branch URLs for lines and visual ranges
Scenarios: `git: github.com current-line branch URL is copied`, `git: Enterprise GitHub current-line branch URL is copied`, `git: Visual selection copies an ordered line range`, `git: A branch without an upstream is copied`
- [x] 3.1 Write the four scenarios in `tests/integration/git/test_file_url.lua`, invoking `git.copy_file_url` through the real picker in populated repositories and asserting register `+`; run each scenario with `make test FILE=tests/integration/git/test_file_url.lua CASE="<scenario title>"` and see it fail
- [x] 3.2 Add typed pure remote/path/ref encoding and blob URL construction in `lua/gleb/git/file_url.lua`, then have `lua/gleb/git/actions.lua` asynchronously resolve `origin`, root, tracked repository-relative path, and attached local branch from the captured buffer and copy the current line or captured ordered visual range
- [x] 3.3 Run each scenario with `make test FILE=tests/integration/git/test_file_url.lua CASE="<scenario title>"` and see all four pass

## 4. Preserve the clipboard when a branch file URL is unavailable
Scenarios: `git: Unavailable file URL input preserves the clipboard`
- [x] 4.1 Write `git: Unavailable file URL input preserves the clipboard` in `tests/integration/git/test_file_url.lua`, invoking the real picker without `origin`, at detached HEAD, and on an untracked file; run `make test FILE=tests/integration/git/test_file_url.lua CASE="Unavailable file URL input preserves the clipboard"` and see it fail
- [x] 4.2 Add short ERROR notifications for each unavailable input and validate the captured buffer before async completion without changing register `+`
- [x] 4.3 Run `make test FILE=tests/integration/git/test_file_url.lua CASE="Unavailable file URL input preserves the clipboard"` and see it pass

## Agent decisions

- URL encoding uses uppercase byte-wise percent escapes so UTF-8 and reserved characters have deterministic GitHub-compatible output.
- Unavailable-input notifications name the failed resolution stage so errors stay short while distinguishing origin, branch, and file failures.
