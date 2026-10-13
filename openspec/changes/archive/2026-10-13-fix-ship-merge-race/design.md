## Context
`ship.py` is a uv script node that runs in the run's worktree. It merges the run branch in whichever checkout has `auto` checked out (`base_checkout()`), or in a temporary worktree if there is none. Archon runs nodes of different runs fully in parallel and has no cross-run serialization. All worktrees of the repo share one common git dir (`git rev-parse --git-common-dir`), so a lock file there is visible to every run on the host.

## Goals / Non-Goals
**Goals:** one merge into `auto` at a time, a checkout that is never left mid-merge, and a conflict path that ends with a gated merge instead of a failed run.

**Non-Goals:** cross-host locking. Locking anything other than the merge itself: archive, commit and gate run unlocked.

## Decisions
- **Lock primitive: an `O_CREAT|O_EXCL` file `<common-dir>/nvim-ship.lock` holding the pid.** Waiters poll every 0.5 s up to `SHIP_LOCK_TIMEOUT` seconds (default 600) and then fail with the pid of the holder. If the holder is dead (`os.kill(pid, 0)` raises `ProcessLookupError`), or the file is empty or unparsable, the waiter removes the file and retries the exclusive create, so only one taker wins. The holder releases the lock in a `finally` and removes the file only if it still holds its own pid.
  - Alternative `fcntl.flock`: the kernel releases it automatically, but the pid-based stale recovery was requested and stays inspectable (`cat` the file). `flock` also gives no holder pid for the timeout message.
  - Alternative `git`'s own `index.lock`: not owned by us, and its failures are exactly the race we are fixing.
- **Lock scope: only the merge in the `auto` checkout.** That covers the clean-tree check, `git merge`, and the abort/verify. Archive, commit and gate stay outside, so a slow gate never blocks other runs.
- **Abort path:** record `HEAD` before merging. On a non-zero merge, run `git merge --abort`, then verify there is no `MERGE_HEAD` and nothing in `git status --porcelain --untracked-files=no`. If that check fails, run `git reset --merge <pre-merge HEAD>`, which is safe because the clean-tree check passed under the same lock just before. Untracked files the merge created are left alone; the guard ignores them.
- **Conflict detection:** after the abort, run `git merge-tree --write-tree --name-only auto <branch>` (git ≥ 2.38). It lists the conflicting files without touching any checkout. This tells a content conflict apart from other merge failures, such as a hook or a lock, which always fail the run.
- **Reconcile in the workflow, not in ship.** Merging `auto` into the branch conflicts on the same hunks, so resolving them needs an agent. ship only reports. `nvim-deliver.yaml` adds a `reconcile` `loop_group` (`max_iterations: 2`, `when: $ship.output.conflict == true`, `until_bash` on its inner ship's `merged`). Its nodes:
  - `resolve`: command `resolve-conflict`. It runs `git merge auto` in the worktree, resolves the conflicts keeping both intents, and commits.
  - `regate`: the existing `gate` script.
  - `reship`: `ship` with `on_conflict: report`, run when `regate` is green and `spec_ok`.

  The workflow's `returns` must then yield whichever ship merged. If Archon cannot select that from two nodes, a final script node `shipped` merges the two outputs.
  - Alternative: rebase the branch onto `auto` inside ship. That fails on the same conflicts and rewrites the history the review checked.
- **`on_conflict` input:** the default `fail` keeps `plugin-update`'s one-line ship unchanged. `nvim-deliver` passes `report`.

## Risks / Trade-offs
- [A pid gets reused after a crash, so a stale lock looks live] → the timeout fails the run with the holder's pid in the message, and `docs/workflow.md` says to delete the file.
- [The `resolve` agent keeps only one side of a conflict] → `regate` runs `make check` and the trace again. If that is red after the last pass, the run fails and keeps the branch.
- [Archon `loop_group` with a `when` on its group node is untested here] → `make loop-validate` must pass. A manual run with a forced conflict is listed as a follow-up.
