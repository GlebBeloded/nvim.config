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

- Capability: `git`.
- Product code: `lua/gleb/git/changes/git.lua`; tests: `tests/integration/git/test_changes.lua`,
  `tests/integration/git/test_changes_stage.lua`, and `tests/integration/git/test_changes_actions.lua`.
- No plugin dependency is added, removed, or upgraded, and no core keymap changes.
- Out of scope: changing Git mutations, panel rendering, or user-facing staging and commit semantics.

## Evidence

- `tests/integration/git/test_changes_stage.lua:127-130` polls plain `git diff --quiet` every 50 ms while the
  child may still be running the staging mutation; `tests/integration/git/test_changes_actions.lua:249-253`
  documents and avoids the same optional-index-lock race for a concurrent checkout.
- `tests/integration/git/test_changes_stage.lua:8,118-130` uses a fixed 3000 ms budget and repeatedly invokes Git
  to infer completion instead of waiting for the recorded child process.
- `lua/gleb/git/changes/git.lua:23-29,50-80` shows the shared runner does not set a lock policy, while the two
  refresh commands independently carry `--no-optional-locks`; setting the environment for refresh reads makes the
  lock policy explicit and prevents a future read-command change from reintroducing the race.
- `tests/integration/git/test_changes_actions.lua:8,137-143` uses an unscaled fixed budget for commit-result
  notifications even though the popup wait at `tests/integration/git/test_changes_actions.lua:100-108` scales with
  `H.load_factor()`.
