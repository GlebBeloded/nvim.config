## Why
Every loop worktree's `make e2e` syncs into the same guest checkout (`$GUEST_REPO`) with `rsync --delete` (`tests/sandbox/sandbox.sh` `sync_repo`), then runs `restore_guest` and `make e2e-local` from it. With several worktrees gating at once, one run's sync replaces another's checkout mid-run. Seen in the `fix-diff-preview-codediff-crash` gate: `zsh:1: no such file or directory: …/tests/sandbox/guest_restore.sh` (exit 127), because a concurrent worktree forked before `guest_restore.sh` existed had just synced over the guest checkout. The e2e result then belongs to neither branch.

Kind: bug

## What Changes
- Concurrent `make e2e` runs from different checkouts no longer share one guest checkout. Design picks the mechanism (e.g. a host-side lock held from `sync_repo` to the end of `e2e-local`, or a guest checkout per host checkout).
- A run waiting on another one says so in its output instead of failing.

## Capabilities
### Modified Capabilities
- `shortcuts`: the e2e sandbox run is isolated from concurrent runs.

## Impact
- Code: `tests/sandbox/sandbox.sh`, `docs/testing.md` (sandbox section).
- Plugins: none added, removed or upgraded.
- Core keymaps: unchanged.
- Out of scope: the `smoke-startup` budget under host load (load average ~70-80 while many worktrees gate at once).
