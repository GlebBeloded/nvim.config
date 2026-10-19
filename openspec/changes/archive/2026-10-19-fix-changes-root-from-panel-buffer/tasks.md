## 1. Keep panel-opened files independent
Scenarios: `git: Changes panel file is an independent normal buffer`
- [x] 1.1 Write the test `git: Changes panel file is an independent normal buffer` in `tests/integration/git/test_changes_diff.lua`, driving `<CR>` on the populated `b.txt` row, and see it fail
- [x] 1.2 Make `open_file` leave the selected path in a listed normal file buffer that remains valid independently of the Changes panel
- [x] 1.3 Run `make test FILE=tests/integration/git/test_changes_diff.lua CASE="Changes panel file is an independent normal buffer"` and see it pass

## 2. Resolve review roots only from real paths
Scenarios: `git: Cmd+G from a non-file buffer uses a real directory`
- [x] 2.1 Write the test `git: Cmd+G from a non-file buffer uses a real directory` in `tests/integration/git/test_changes.lua`, driving the real `changes.review` action from a named non-file buffer in the populated `dirty` fixture, and see it fail with the invalid `cwd`
- [x] 2.2 Make repository discovery distinguish real file buffers from non-file buffers and fall back to an existing directory without passing a panel URI to Git
- [x] 2.3 Run `make test FILE=tests/integration/git/test_changes.lua CASE="Cmd+G from a non-file buffer uses a real directory"` and see it pass

## Agent decisions

- Treat non-empty `buftype` as the primary non-file signal and also reject full URI schemes, so repository discovery keeps unnamed and plugin buffers out of Git's `cwd`.
