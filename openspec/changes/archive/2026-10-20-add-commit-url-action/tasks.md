## 1. Register the contextual commit action
Scenarios: `git: Copy Commit URL is offered for a commit row`, `git: Copy Commit URL is absent away from commit rows`
- [x] 1.1 Write the tests `git: Copy Commit URL is offered for a commit row` and `git: Copy Commit URL is absent away from commit rows` in `tests/integration/git/test_changes_commit_url.lua`; drive the populated `billing-branch` commit view and the real Find Action picker, run `make test FILE=tests/integration/git/test_changes_commit_url.lua CASE="Copy Commit URL is offered for a commit row"`, and see it fail
- [x] 1.2 Add the unbound `changes.copy_commit_url` catalog entry and a named context predicate that accepts only a selected Branch commit row
- [x] 1.3 Run `make test FILE=tests/integration/git/test_changes_commit_url.lua CASE="Copy Commit URL is offered for a commit row"` and `make test FILE=tests/integration/git/test_changes_commit_url.lua CASE="Copy Commit URL is absent away from commit rows"` and see them pass

## 2. Copy github.com commit URLs
Scenarios: `git: github.com commit URL is copied`
- [x] 2.1 Write the test `git: github.com commit URL is copied` in `tests/integration/git/test_changes_commit_url.lua`; select the action through the real Find Action picker on a populated commit row, run `make test FILE=tests/integration/git/test_changes_commit_url.lua CASE="github.com commit URL is copied"`, and see it fail
- [x] 2.2 Parse the selected row's full hash and the repository's HTTPS, `ssh://` or SCP-like `origin`, then copy the github.com `/commit/<full-sha>` URL to register `+`
- [x] 2.3 Run `make test FILE=tests/integration/git/test_changes_commit_url.lua CASE="github.com commit URL is copied"` and see it pass

## 3. Support arbitrary GitHub Enterprise hosts
Scenarios: `git: Enterprise GitHub commit URL is copied`
- [x] 3.1 Write the test `git: Enterprise GitHub commit URL is copied` in `tests/integration/git/test_changes_commit_url.lua`; drive the real action on the populated `billing-branch` fixture, run `make test FILE=tests/integration/git/test_changes_commit_url.lua CASE="Enterprise GitHub commit URL is copied"`, and see it fail
- [x] 3.2 Generalize web-base construction from github.com to the remote's parsed host and optional port without an enterprise-host allowlist
- [x] 3.3 Run `make test FILE=tests/integration/git/test_changes_commit_url.lua CASE="Enterprise GitHub commit URL is copied"` and see it pass

## 4. Report a missing origin safely
Scenarios: `git: Missing origin preserves the clipboard`
- [x] 4.1 Write the test `git: Missing origin preserves the clipboard` in `tests/integration/git/test_changes_commit_url.lua`; drive the real action on a populated commit row in a repository without `origin`, run `make test FILE=tests/integration/git/test_changes_commit_url.lua CASE="Missing origin preserves the clipboard"`, and see it fail
- [x] 4.2 Preserve register `+` and emit an ERROR notification when the remote cannot produce a commit URL
- [x] 4.3 Run `make test FILE=tests/integration/git/test_changes_commit_url.lua CASE="Missing origin preserves the clipboard"` and see it pass

## Agent decisions

- “Gives the URL” means copy to register `+`, matching the existing `:Gitlink` behavior; the action is intentionally unbound and recognizes GitHub Enterprise by remote shape instead of a hostname allowlist.
