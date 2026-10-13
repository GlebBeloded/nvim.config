## Context
There is one Lume guest with one checkout path (`/Users/lume/nvim`) and one Aqua session (Alacritty + zellij). Every worktree's gate runs `sandbox.sh e2e` against it. The gates also run the stack and smoke layers on the host at the same time, so the host load average reaches 45-73 on 14 cores. No new UI is involved. The change is to the structure of the test tooling: a new lock helper, and one load factor that the timing checks share.

## Decisions

### 1. One host-side mkdir lock, not a guest checkout per worktree
- Proposed A (picked): a lock in `$SANDBOX_STATE/lock`, taken once at the top-level command dispatch of `sandbox.sh` for `up`, `provision`, `down`, `e2e` and `ssh`, and released by an `EXIT` trap. `provision()`, called from inside `e2e()`, does not lock again. `status` does not lock.
- Proposed B: a per-worktree `GUEST_REPO`. Rejected. It still shares the Aqua session, `org.alacritty` defaults, the guest plugin dir and the zellij session dir, so runs would still collide.
- No `flock(1)` on macOS. `mkdir` is atomic on APFS and works in bash without dependencies (shlock and lockf were considered: `lockf` holds a lock only while a child runs, and wrapping every `gssh` that way would be awkward).
- `tests/sandbox/lock.sh` is sourced by `sandbox.sh`. It provides `sandbox_lock <dir>` with small named functions: `lock_try`, `lock_owner_alive`, `lock_reclaim`, `lock_wait`, `lock_release`.
  - Owner record: `<dir>/owner` holds `<pid> <start time>` (`ps -o lstart= -p <pid>`) and a line with `$ROOT`. Alive means `kill -0` succeeds and the start time matches, which survives pid reuse.
  - Reclaim: `mv <dir> <dir>.stale.$$` and then `rm -rf`. Only one reclaimer's `mv` succeeds, so two waiters never both take the lock.
  - Wait: polls every `SANDBOX_LOCK_POLL` s (default 1) and prints one `sandbox: waiting for <dir> (pid N, <root>)` line. It gives up after `SANDBOX_LOCK_TIMEOUT` s (default 3600, longer than a cold boot + provision) with `die`.
  - The owner is `$$` of `sandbox.sh`. The lock spans `gui "make -s e2e-local"`, which runs synchronously over ssh.
  - The `E2E=0` skip exits before the lock. The `SANDBOX_START=0` "sandbox down" check runs after it, because the holder may be booting the VM.

### 2. Load factor, not a host-wide timing lock
- Proposed A (picked): `H.load_factor()` = `max(1, loadavg[1] / available_parallelism())`. `tests/shortcuts/stack.lua` scales the `M.wait_for` timeout (default and explicit) and `CLI_TIMEOUT_MS` by it. Smoke gets a small `tests/smoke/budget.lua` (`startup_budget(base_ms)`) so the budget is testable from a child, and `run.lua` uses it for both the median and the fastest-of-9 checks. The result line shows the factor whenever it is above 1.
- Proposed B: a host-wide lock around `smoke-startup` and `stack`. Rejected. It slows every gate, and the load still comes from other worktrees' `test` and `chain` layers, which run at the same time.
- Idle hosts are unaffected: with load ≤ CPU count the factor is exactly 1. At the logged worst case (fastest 1128 ms at load 47.9 / 14 = 3.4) the budget becomes 1370 ms, which is still far below a real regression on an idle host.
- The 1-min average lags. It is read when the check is judged (`run.lua`) and when a wait starts (`stack.lua`), which is good enough for a timing check that is already noisy.

## Risks
- A `sandbox.sh` killed with SIGKILL leaves the lock until the next caller reclaims it. That is the stale path, covered by a scenario.
- A hung e2e holds the lock for everyone. The bound is the waiters' `SANDBOX_LOCK_TIMEOUT` and the harness's own watchdog.
