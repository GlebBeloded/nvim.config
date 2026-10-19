## 1. Fake gh routing and canned responses
Scenarios: `pr: PR threads are fetched with gh api graphql`, `pr: No pull request runs no GraphQL`
- [ ] 1.1 Write both scenarios in `tests/integration/pr/test_threads.lua` against a fresh `billing-branch` copy with `FAKE_GH_DIR` and `FAKE_GH_LOG`, and see them fail
- [ ] 1.2 Add `FAKE_GH_DIR` routing to `tests/fixtures/bin/gh` (design.md, Decision 7) without changing its default mode, add `tests/fixtures/gh/pr482.lua` (design.md, Fixture) and the helper that writes the files and sets the child env
- [ ] 1.3 Add `lua/gleb/pr/{init,gh}.lua` with `refresh` and `get`, the `ReviewThreads` query and the argv/env of Decision 2; run `make test FILE=tests/integration/pr/test_threads.lua` and see them pass

## 2. Thread model
Scenarios: `pr: PR thread model keeps the GraphQL fields`, `pr: PR thread author falls back to ghost`, `pr: Open PR threads are counted`
- [ ] 2.1 Write the scenarios in `tests/unit/pr/test_threads.lua` from the `pr482` page, and see them fail
- [ ] 2.2 Add `lua/gleb/pr/threads.lua` (`parse`, `open_count`) with the LuaCATS types of Decision 1
- [ ] 2.3 Run `make test FILE=tests/unit/pr/test_threads.lua` and see them pass

## 3. Pagination
Scenarios: `pr: PR thread pages follow the end cursor`, `pr: Long PR threads load every comment`
- [ ] 3.1 Write the scenarios in `tests/unit/pr/test_gh.lua` with a stub `run`, and see them fail
- [ ] 3.2 Implement `fetch_threads` paging and the `ThreadComments` query
- [ ] 3.3 Run `make test FILE=tests/unit/pr/test_gh.lua` and see them pass

## 4. Line mapping and anchors
Scenarios: `pr: Thread line shifts below inserted lines`, `pr: Thread line inside a replaced block keeps its offset`, `pr: Thread line on a removed line is unmapped`, `pr: PR threads map onto the working file`, `pr: PR threads follow unsaved edits`, `pr: A PR thread on a removed line is unmapped`, `pr: An outdated PR thread anchors at its original commit`, `pr: A PR thread at a missing commit is unmapped`, `pr: Left-side and file PR threads are unmapped`
- [ ] 4.1 Write the three mapping tables in `tests/unit/pr/test_threads.lua` and the `locate` scenarios in `tests/integration/pr/test_threads.lua`, and see them fail
- [ ] 4.2 Implement `map_line` and `anchor` (Decisions 3 and 4), then `locate` with the `git show` and `git cat-file -e` loads and the blob cache
- [ ] 4.3 Run both files and see them pass

## 5. Cache, event and refresh triggers
Scenarios: `pr: PR threads are cached per head`, `pr: A new PR head fetches the threads again`, `pr: PR thread updates fire an event`, `pr: pr.refresh fetches the threads again`, `pr: Opening the review panel fetches the threads`, `pr: Writing a file fetches the threads once`, `pr: A trigger during a fetch queues one more`, `pr: pr.refresh without a pull request`
- [ ] 5.1 Write the scenarios in `tests/integration/pr/test_threads.lua`, counting `git show` runs with a `vim.system` spy in the child, and see them fail
- [ ] 5.2 Implement the per-head cache, generations, `in_flight`/`pending`, the `gleb_pr` augroup (`BufWritePost` debounce and throttle, `GlebGitBaseChanged`), the refresh call in the opening `changes.review`, `User GlebPrThreads`, and the INFO notifications
- [ ] 5.3 Run `make test FILE=tests/integration/pr/test_threads.lua` and see them pass

## 6. Errors
Scenarios: `pr: PR fetch failures are classified`, `pr: A failed PR fetch warns once and keeps the threads`, `pr: pr.refresh always reports a failure`
- [ ] 6.1 Write the classification table in `tests/unit/pr/test_gh.lua` and the two fake-`gh` failure cases in `tests/integration/pr/test_threads.lua`, and see them fail
- [ ] 6.2 Implement `gh.failure` (Decision 6), the reported-kinds set and its reset on success
- [ ] 6.3 Run both files and see them pass

## 7. Action
Scenarios: `pr: pr.refresh is an unbound Find Action entry`
- [ ] 7.1 Write the scenario in `tests/integration/pr/test_threads.lua` and see it fail
- [ ] 7.2 Add `lua/gleb/pr/actions.lua` with `pr.refresh` (rule 1.9) and register it; no entry in `settings/keymap.json`
- [ ] 7.3 Run the file, then `make check`, and see them pass
