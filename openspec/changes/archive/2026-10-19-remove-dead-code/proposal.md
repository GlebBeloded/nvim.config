## Why

Kind: refactor

Depends: file-tree-performance, fix-file-tree-watch-limit

Dead code found on `auto` (2026-10-19 inventory, `require`/caller search over lua/ and tests/):

- Certainly dead: `lua/gleb/database/picker.lua` (0 bytes, never required); `M.command_list`
  (`lua/gleb/actions/adapters/init.lua:112`, no caller).
- Production code only tests use: `M.folder_status` (`lua/gleb/file_tree/model.lua:219`, only
  `tests/unit/file-tree/test_model.lua:155-158`; duplicates the private `visible_folder_status` at `model.lua:250` minus
  the ignore filter); `lua/gleb/actions/adapters/lazy.lua` (only `tests/integration/actions/test_adapters.lua` and
  `tests/integration/find-action/test_run.lua:293`; lazy keys go through the ft-scoped `lazy.close` action,
  `plugins/actions.lua:12`); `M.stop_all` (`lua/gleb/file_tree/watch.lua:246`, only `test_project_ops.lua:1353`).
- Cutover leftover: `tests/screen/find-action/test_palette.lua:29,354` still titles the `changes.review` fixture "Open
  Differ".

## What Changes

- Delete the certainly-dead code.
- For each test-only production function: if the test only exercises that function, test the production path it
  duplicates instead (e.g. `visible_folder_status` through the model's public rows) and delete it; if it is a deliberate
  API or test seam (`watch.stop_all` for teardown, `diff/engine` `compare_words`/`compare_chars`, `languages.contract.check`,
  `actions.audit`), keep it and record why in tasks.md `## Agent decisions`.
- Rename the "Open Differ" fixture title to the action's current title and re-approve nothing else.
- No behaviour change; every scenario keeps its test.

## Impact

- Cleanup touches `lua/gleb/database/picker.lua`, `lua/gleb/actions/adapters/init.lua`,
  `lua/gleb/actions/adapters/lazy.lua`, `lua/gleb/file_tree/model.lua`, and their existing tests and screenshots.
- `diff: CJK characters are words of their own` still holds because the public inner-comparison test seam and word engine remain unchanged.
- `diff: An emoji change spans its whole character` still holds because the public inner-comparison test seam and character engine remain unchanged.
- `diff: Punctuation separates words` still holds because the public inner-comparison test seam and word engine remain unchanged.
- `diff: Every IntelliJ word case passes` still holds because `compare_words` remains available to the unchanged golden suite.
- `diff: Every IntelliJ char case passes` still holds because `compare_chars` remains available to the unchanged golden suite.
- `diff: Random texts keep IntelliJ's inner invariants` still holds because both public inner-comparison entry points remain available to the unchanged invariant suite.
