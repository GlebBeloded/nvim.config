## 1. Fake gh routing and first fetch
Scenarios: `pr: PR threads are fetched with gh api graphql`, `pr: No pull request runs no GraphQL`
- [x] 1.1 Write both scenarios in `tests/integration/pr/test_threads.lua`, driving `require("gleb.pr").refresh(root)` against a fresh `billing-branch` copy with `FAKE_GH_DIR` and `FAKE_GH_LOG`, and see them fail
- [x] 1.2 Add `FAKE_GH_DIR` routing to `tests/fixtures/bin/gh` without changing its default mode, add `tests/fixtures/gh/pr482.lua` and its fixture helper, then add `lua/gleb/pr/{init,gh}.lua` with `refresh`, `get`, and the `ReviewThreads` argv and environment
- [x] 1.3 Run `make test FILE=tests/integration/pr/test_threads.lua CASE="PR threads are fetched with gh api graphql"` and `make test FILE=tests/integration/pr/test_threads.lua CASE="No pull request runs no GraphQL"` and see them pass

## 2. Thread model
Scenarios: `pr: PR thread model keeps the GraphQL fields`, `pr: PR thread author falls back to ghost`, `pr: Open PR threads are counted`
- [ ] 2.1 Write the scenarios in `tests/unit/pr/test_threads.lua`, driving `require("gleb.pr.threads").parse` and `open_count` with the `pr482` page, and see them fail
- [ ] 2.2 Add the typed `parse` and `open_count` implementation to `lua/gleb/pr/threads.lua`
- [ ] 2.3 Run `make test FILE=tests/unit/pr/test_threads.lua CASE="PR thread model keeps the GraphQL fields"`, `make test FILE=tests/unit/pr/test_threads.lua CASE="PR thread author falls back to ghost"`, and `make test FILE=tests/unit/pr/test_threads.lua CASE="Open PR threads are counted"` and see them pass

## 3. Pagination
Scenarios: `pr: PR thread pages follow the end cursor`, `pr: Long PR threads load every comment`
- [ ] 3.1 Write the scenarios in `tests/unit/pr/test_gh.lua`, driving `require("gleb.pr.gh").fetch_threads(pr, run)` with a stub runner, and see them fail
- [ ] 3.2 Implement thread paging and the `ThreadComments` query in `lua/gleb/pr/gh.lua`
- [ ] 3.3 Run `make test FILE=tests/unit/pr/test_gh.lua CASE="PR thread pages follow the end cursor"` and `make test FILE=tests/unit/pr/test_gh.lua CASE="Long PR threads load every comment"` and see them pass

## 4. Line mapping
Scenarios: `pr: Thread line shifts below inserted lines`, `pr: Thread line inside a replaced block keeps its offset`, `pr: Thread line on a removed line is unmapped`
- [ ] 4.1 Write the three tables in `tests/unit/pr/test_threads.lua`, driving `require("gleb.pr.threads").map_line`, and see them fail
- [ ] 4.2 Implement `map_line` with `vim.text.diff` hunks in `lua/gleb/pr/threads.lua`
- [ ] 4.3 Run `make test FILE=tests/unit/pr/test_threads.lua CASE="Thread line shifts below inserted lines"`, `make test FILE=tests/unit/pr/test_threads.lua CASE="Thread line inside a replaced block keeps its offset"`, and `make test FILE=tests/unit/pr/test_threads.lua CASE="Thread line on a removed line is unmapped"` and see them pass

## 5. Working-file anchors
Scenarios: `pr: PR threads map onto the working file`, `pr: PR threads follow unsaved edits`, `pr: A PR thread on a removed line is unmapped`
- [ ] 5.1 Write the scenarios in `tests/integration/pr/test_threads.lua`, driving `require("gleb.pr").locate(0)` on the populated `billing-branch` fixture buffer, and see them fail
- [ ] 5.2 Implement `anchor` and `locate` with buffer lines, `git show`, and the bounded `oid:path` blob cache
- [ ] 5.3 Run `make test FILE=tests/integration/pr/test_threads.lua CASE="PR threads map onto the working file"`, `make test FILE=tests/integration/pr/test_threads.lua CASE="PR threads follow unsaved edits"`, and `make test FILE=tests/integration/pr/test_threads.lua CASE="A PR thread on a removed line is unmapped"` and see them pass

## 6. Exceptional anchors
Scenarios: `pr: An outdated PR thread anchors at its original commit`, `pr: A PR thread at a missing commit is unmapped`, `pr: Left-side and file PR threads are unmapped`
- [ ] 6.1 Write the scenarios in `tests/integration/pr/test_threads.lua`, driving `require("gleb.pr").locate(0)` with the served thread variants, and see them fail
- [ ] 6.2 Complete `anchor` and `locate` for original commits, missing commits, left-side threads, and file threads
- [ ] 6.3 Run `make test FILE=tests/integration/pr/test_threads.lua CASE="An outdated PR thread anchors at its original commit"`, `make test FILE=tests/integration/pr/test_threads.lua CASE="A PR thread at a missing commit is unmapped"`, and `make test FILE=tests/integration/pr/test_threads.lua CASE="Left-side and file PR threads are unmapped"` and see them pass

## 7. Cache and update event
Scenarios: `pr: PR threads are cached per head`, `pr: A new PR head fetches the threads again`, `pr: PR thread updates fire an event`
- [ ] 7.1 Write the scenarios in `tests/integration/pr/test_threads.lua`, driving `get`, `locate`, and a forced `gleb.git.base` refresh against the populated fixture, and see them fail
- [ ] 7.2 Implement the per-root, per-head cache, generation checks, blob reuse, the `GlebGitBaseChanged` listener, and `User GlebPrThreads`
- [ ] 7.3 Run `make test FILE=tests/integration/pr/test_threads.lua CASE="PR threads are cached per head"`, `make test FILE=tests/integration/pr/test_threads.lua CASE="A new PR head fetches the threads again"`, and `make test FILE=tests/integration/pr/test_threads.lua CASE="PR thread updates fire an event"` and see them pass

## 8. Refresh triggers
Scenarios: `pr: pr.refresh fetches the threads again`, `pr: Opening the review panel fetches the threads`, `pr: Writing a file fetches the threads once`, `pr: A trigger during a fetch queues one more`, `pr: pr.refresh without a pull request`
- [ ] 8.1 Write the scenarios in `tests/integration/pr/test_threads.lua`, driving `pr.refresh`, `changes.review`, `:write`, and concurrent refreshes against the real action and populated fixture, and see them fail
- [ ] 8.2 Implement forced refresh notifications, `in_flight`/`pending`, the `gleb_pr` write debounce and throttle, and the opening hook in `lua/gleb/git/changes/init.lua`
- [ ] 8.3 Run each task scenario with `make test FILE=tests/integration/pr/test_threads.lua CASE="<scenario title>"` and see it pass

## 9. Errors
Scenarios: `pr: PR fetch failures are classified`, `pr: A failed PR fetch warns once and keeps the threads`, `pr: pr.refresh always reports a failure`
- [ ] 9.1 Write the classification table in `tests/unit/pr/test_gh.lua` and the fake-`gh` failure scenarios in `tests/integration/pr/test_threads.lua`, driving the real failure parser and refresh entry point, and see them fail
- [ ] 9.2 Implement `gh.failure`, the per-root reported-kind set, cache preservation, and reset after success
- [ ] 9.3 Run `make test FILE=tests/unit/pr/test_gh.lua CASE="PR fetch failures are classified"`, `make test FILE=tests/integration/pr/test_threads.lua CASE="A failed PR fetch warns once and keeps the threads"`, and `make test FILE=tests/integration/pr/test_threads.lua CASE="pr.refresh always reports a failure"` and see them pass

## 10. Refresh action
Scenarios: `pr: pr.refresh is an unbound Find Action entry`
- [ ] 10.1 Write the scenario in `tests/integration/pr/test_threads.lua`, driving the real Find Action registry, and see it fail
- [ ] 10.2 Add `lua/gleb/pr/actions.lua` with `pr.refresh`, register it from `init.lua`, and leave `settings/keymap.json` unchanged
- [ ] 10.3 Run `make test FILE=tests/integration/pr/test_threads.lua CASE="pr.refresh is an unbound Find Action entry"`, then `make check`, and see them pass
