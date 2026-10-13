# Tasks

## 1. Preserve state after successful ranged commands

Scenarios: "git: Gitlink copies range URL", "git: Gitlink range preserves editor state".

- [x] 1.1 **Failing tests.** Extend `tests/integration/git/test_gitlink.lua` to assert that the existing visual-range case restores its cursor, and add the Normal-mode `:3,5Gitlink` case with a distinct prior selection whose cursor and `'<`/`'>` marks remain unchanged. Run `make test-integration FILE=tests/integration/git/test_gitlink.lua`; the new assertions fail.
- [x] 1.2 **Implement.** In `lua/gleb/git/gitlink.lua`, snapshot the ranged command's cursor and visual marks, leave the temporary Visual selection before restoring them, and annotate the test `git()` helper with LuaCATS. Rerun the command from 1.1; both scenarios pass.

## 2. Restore state when permalink generation fails

Scenario: "git: Gitlink range failure restores editor state".

- [x] 2.1 **Failing test.** Add an integration case that makes ranged permalink generation raise a known error, invokes `:3,5Gitlink` from Normal mode after a distinct prior selection, and asserts the original error plus restored mode, cursor, and `'<`/`'>` marks. Run `make test-integration FILE=tests/integration/git/test_gitlink.lua CASE="Gitlink range failure restores editor state"`; it fails because cleanup is skipped.
- [x] 2.2 **Implement.** Protect permalink generation, always perform ranged cleanup, and re-raise the captured error without decoration. Rerun the command from 2.1 and then the full test file; all three changed scenarios pass.
