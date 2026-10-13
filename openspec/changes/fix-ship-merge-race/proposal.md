## Why
Parallel loop runs reach the `ship` node at the same time, and `.archon/scripts/ship.py` merges every run branch into the same `auto` checkout (`~/.config/nvim`) without any mutual exclusion. The losing merges fail partway, and their unchecked `git merge --abort` can leave `MERGE_HEAD` and a staged index behind. Every later ship then stops at the "has uncommitted changes" guard, so one race blocks the whole loop until someone fixes the checkout by hand. A real content conflict with `auto` also just fails the run. Root cause, with a reproduction: `artifacts/runs/46a1d0aa-ebfd-45fd-8ecb-b22554c9158b/root-cause.md`.

Kind: bug

## What Changes
- `ship.py` serializes the merge into `auto` with a host-side lock file in the repo's common git dir. The file holds the owner's pid, waiters poll it, and a lock whose pid is no longer alive is taken over. The lock is always released, including on failure.
- `ship.py` never leaves the `auto` checkout mid-merge. On any failed merge it aborts the merge and checks that there is no `MERGE_HEAD` and no staged or modified tracked files. If the abort did not get there, it resets with `git reset --merge` to the commit `auto` was at before the merge. The run then fails with the branch kept.
- When the merge into `auto` conflicts, ship reports the conflict as a JSON result (`merged: false, conflict: true`, conflicting files) and leaves `auto` untouched, but only when its input `on_conflict` is `report`. Otherwise the run fails, as it does today.
- `nvim-deliver.yaml` gets a reconcile loop after `ship`, run only when ship reports a conflict, with at most 2 passes. In it, an agent node (new command `resolve-conflict`) merges `auto` into the run branch inside the run worktree and resolves the conflicts. Then `gate` runs again, and ship retries if the gate is green. If the loop runs out of passes, the run fails and the branch is kept.
- New scenarios in the `loop` capability, with unit tests that run the real `ship.py` against throwaway repos.

## Capabilities
### New Capabilities
None

### Modified Capabilities
- `loop`: adds the requirements "Ship merges into auto one at a time and never leaves it mid-merge" and "Ship reports a conflict for reconcile".

## Impact
- Code: `.archon/scripts/ship.py`, `.archon/workflows/nvim-deliver.yaml` (`ship` input `on_conflict`, `conflict` field in its output, reconcile loop), new `.archon/commands/resolve-conflict.md`. New test file `tests/unit/loop/test_ship.lua`. `docs/workflow.md` gets one line on the lock and the reconcile loop.
- Plugins: none added, removed or upgraded.
- Core keymaps: unchanged.
- Out of scope:
  - `plugin-update.yaml`'s own ship of the lock line keeps `on_conflict` at its default, so a conflict fails cleanly and nothing reconciles.
  - Recovering an `auto` checkout that was already left dirty by an earlier run: ship still refuses it, with the same message.
  - Changing Archon itself (a per-node concurrency limit would be upstream work).
  - Re-gating when `auto` moved without a conflict.
