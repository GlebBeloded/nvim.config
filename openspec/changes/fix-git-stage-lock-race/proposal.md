## Why

Kind: bug
Priority: high

Loop audit (2026-10-20): "git: Changes panel A stages everything" (`tests/integration/git/test_changes_stage.lua`) and
"Changes panel gc commits confirmed message" fail under load. Independent review: the test's `wait_worktree_clean`
polls `git diff --quiet` every 50 ms, and `git diff` takes the optional `index.lock` to refresh the index, while the
child's `git add -A` needs that lock and fails when it is held. Background status polling in the product may race the
same way with the user's own git commands.

## What Changes

- Polling and read-only git calls (in the tests' waits and in the product's status refreshes) run with
  `GIT_OPTIONAL_LOCKS=0`, so they never take `index.lock` from a write.
- The stage tests wait for the recorded `git add` to complete, then check git once; their async waits scale with
  `H.load_factor()`.

## Impact

- `lua/gleb/git/` status/refresh calls, `tests/integration/git/test_changes_stage.lua`, `test_changes_actions.lua`.
