## Why
Every loop worktree's `make e2e` syncs into the same guest checkout (`$GUEST_REPO`) with `rsync --delete` (`tests/sandbox/sandbox.sh` `sync_repo`), then runs `restore_guest` and `make e2e-local` from it, in the one GUI session of the guest. With several worktrees gating at once, one run's sync replaces another's checkout mid-run. Seen in the `fix-diff-preview-codediff-crash` gate: `zsh:1: no such file or directory: …/tests/sandbox/guest_restore.sh` (exit 127), because a concurrent worktree forked before `guest_restore.sh` existed had just synced over the guest checkout. The e2e result then belongs to neither branch.

The same parallel gates load the host to a load average of 45-73 (14 cores). `smoke-startup` then fails its fixed 400 ms budget even on the fastest of 9 samples (430-1130 ms in the run logs). The stack layer's fixed deadlines (`M.wait_for` 10 s, zellij CLI retry 5 s in `tests/shortcuts/stack.lua`) also time out ("timed out waiting for zellij focus on the cat pane"). Every logged stack timeout came with load ≥ 45. Root cause: `artifacts/runs/2b1e1e40-…/root-cause.md`.

Kind: bug

## What Changes
- A host-side lock serializes every `sandbox.sh` command that changes the guest (`up`, `provision`, `down`, `e2e`, `ssh`). It is an `mkdir` lock in `$SANDBOX_STATE` (`~/.cache/nvim-e2e-sandbox`), shared by all worktrees, and it is held from before the sync to the end of `make e2e-local`. A waiting run says so on stderr instead of failing. A lock whose owner process is gone is reclaimed. `status` only reads, so it does not lock. In the VM, `e2e` runs the harness directly and does not lock.
- The stack layer's deadlines and the smoke startup budget scale with host load: factor `max(1, 1-min load average / CPU count)`. On an idle host (load ≤ CPU count) the factor is exactly 1, so the 400 ms budget and the 10 s / 5 s deadlines are unchanged.
- Unit tests for the lock helper, for `sandbox.sh` taking it, and for the load factor.

## Capabilities
### Modified Capabilities
- `shortcuts`: the e2e sandbox run is isolated from concurrent runs, and the stack harness deadlines tolerate host load. The smoke startup budget has no capability of its own (test tooling). Its load scaling uses the same helper, and its scenario sits with the harness timing requirement.

## Impact
- Code: `tests/sandbox/sandbox.sh`, new `tests/sandbox/lock.sh`, `tests/helpers.lua` (load factor), `tests/shortcuts/stack.lua`, `tests/smoke/run.lua`, `tests/unit/shortcuts/test_sandbox.lua`, `tests/unit/shortcuts/test_stack_cli.lua`, `docs/testing.md` (Sandbox VM, Smoke details, stack).
- Plugins: none added, removed or upgraded.
- Core keymaps: unchanged.
- Out of scope: a guest checkout per host checkout or several VMs. The guest has a single GUI session, so e2e runs must be serialized anyway. Also out of scope: lowering the gate's own parallelism (`tests/check.sh`, `.archon/scripts/gate.py`) and changing the 400 ms budget itself.
