## 1. Keep refresh reads out of the optional index lock
Scenarios: `git: Changes panel refresh reads avoid optional locks`
- [x] 1.1 Write the test `git: Changes panel refresh reads avoid optional locks` in `tests/integration/git/test_changes.lua`, drive `require("gleb.git.changes.git").refresh` against a populated repository, assert both spawned read processes receive `GIT_OPTIONAL_LOCKS=0`, and see it fail
- [x] 1.2 Make the Changes panel's status and line-stat refresh processes set `GIT_OPTIONAL_LOCKS=0` without applying that environment to Git mutations
- [x] 1.3 Run `make test FILE=tests/integration/git/test_changes.lua CASE="Changes panel refresh reads avoid optional locks"` and see it pass

## 2. Synchronize stage-all completion before inspecting Git
Scenarios: `git: Changes panel A stages everything`
- [x] 2.1 Use the queued under-load failure of `git: Changes panel A stages everything` as the failing evidence, then instrument the real `A` mapping's recorded `git add -A` process in `tests/integration/git/test_changes_stage.lua` so the test can await its completion
- [x] 2.2 Replace the polling `git diff --quiet` completion check with a wait for the recorded `git add -A` process, then inspect Git once with optional locks disabled; scale the file's asynchronous waits with `H.load_factor()`
- [x] 2.3 Run `make test FILE=tests/integration/git/test_changes_stage.lua CASE="Changes panel A stages everything"` and see it pass

## 3. Synchronize root staging before inspecting Git
Scenarios: `git: Changes panel Space on the Changes root stages every tracked file`
- [x] 3.1 Tighten `tests/integration/git/test_changes_stage.lua` to await the real `<Space>` mapping's recorded `git add` process before asserting repository state; with a temporary fault that reports the process complete before it exits, run `make test FILE=tests/integration/git/test_changes_stage.lua CASE="Changes panel Space on the Changes root stages every tracked file"`, see it fail and record the failure, then remove the fault
- [x] 3.2 Reuse the stage-process completion helper and perform the lock-free Git state check once after completion
- [x] 3.3 Run `make test FILE=tests/integration/git/test_changes_stage.lua CASE="Changes panel Space on the Changes root stages every tracked file"` and see it pass

## 4. Scale commit-result waits with host load
Scenarios: `git: Changes panel gc commits confirmed message`
- [x] 4.1 Use the queued under-load failure of `git: Changes panel gc commits confirmed message` as the failing evidence and tighten its real `gc` popup flow in `tests/integration/git/test_changes_actions.lua` to use the load-scaled asynchronous budget
- [x] 4.2 Scale the action test's asynchronous waits with `H.load_factor()` while preserving the existing commit and notification assertions
- [x] 4.3 Run `make test FILE=tests/integration/git/test_changes_actions.lua CASE="Changes panel gc commits confirmed message"` and see it pass

## Agent decisions

- The queued proposal names both timing failures but contains no literal `FAIL in` line to copy, so tasks 2.1 and 4.1 preserve those named failures as the available failing evidence rather than inventing gate output or searching old run artifacts.
- The task 3.1 premature-completion fault exposed partial staging (`a.txt`, `d.txt`) and a dirty 101-file worktree, confirming repository inspection must follow process completion.
- Stage tests use a 10-second load-scaled base budget because the populated 101-file panel can exceed the former 3-second budget under concurrent test load.
