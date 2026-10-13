## Conventions for this change

- Layer: unit (`docs/testing.md`, "Adding a test for a scenario"). It runs on the macOS host with bash, never in a VM.
- Lock tests go in `tests/unit/shortcuts/test_sandbox.lua` and reuse its `tempdir`, `write_executable`, `system` and `sandbox_env` helpers. A lock holder is a background `bash -c 'source <root>/tests/sandbox/lock.sh; sandbox_lock "$1"; sleep N' _ <dir>` started with `vim.system` (not waited), so its pid is known.
- Load tests stub `vim.uv.loadavg` / `vim.uv.available_parallelism` inside the child before calling the function under test (`H.load_factor` reads them on each call, never at require time). Stack load tests go in `tests/unit/shortcuts/test_stack_cli.lua`. The `H.load_factor` and smoke budget tests go in the same file under a `load` set.
- The lock helper's design is in `design.md` decision 1, and the load factor's in decision 2. Plugins: none.

## 1. Lock helper

Scenarios: "The sandbox lock is taken when free and released by its owner", "A second sandbox lock waits for the first and says so", "A sandbox lock left by a dead process is reclaimed", "A sandbox lock wait gives up after SANDBOX_LOCK_TIMEOUT".

- [x] 1.1 Failing tests `shortcuts: The sandbox lock is taken when free and released by its owner`, `shortcuts: A second sandbox lock waits for the first and says so`, `shortcuts: A sandbox lock left by a dead process is reclaimed` and `shortcuts: A sandbox lock wait gives up after SANDBOX_LOCK_TIMEOUT` in `tests/unit/shortcuts/test_sandbox.lua`:
  - For the dead owner, write `<dir>/owner` with the pid of a finished `sh -c 'echo $$'`.
  - The waiter case: the holder sleeps 2 s; the waiter appends a timestamp to a file right after `sandbox_lock` returns, then reads its own `owner`. Assert that timestamp is at or after the holder's exit, the stderr text and the owner pid.
  - The timeout case runs the waiter with `SANDBOX_LOCK_TIMEOUT=1 SANDBOX_LOCK_POLL=0.2` and asserts its code, elapsed time, stderr and `owner`.
  - `make test FILE=tests/unit/shortcuts/test_sandbox.lua` fails, because `tests/sandbox/lock.sh` does not exist.
- [x] 1.2 Add `tests/sandbox/lock.sh` (bash, header comment, sourced, no `set -e` of its own) with `sandbox_lock <dir>` per design decision 1: an owner record of pid, start time and root; atomic reclaim by `mv`; `SANDBOX_LOCK_POLL` / `SANDBOX_LOCK_TIMEOUT`; an `EXIT` trap that releases only the caller's own lock (plus `INT`/`TERM` traps that `exit`, so a Ctrl-C releases it too; `sandbox.sh` sets no other `EXIT` trap). A lock dir with no `owner` file yet counts as alive (its owner is between `mkdir` and the write). Use small named functions.
- [x] 1.3 The four cases pass. `shellcheck tests/sandbox/lock.sh` is clean (`make lint` covers only Lua). `make quick` is green.

## 2. sandbox.sh takes the lock

Scenarios: "sandbox.sh e2e holds the sandbox lock from the sync to the end of the e2e layer", "sandbox.sh e2e waits while another checkout holds the sandbox lock".

- [x] 2.1 Failing tests `shortcuts: sandbox.sh e2e holds the sandbox lock from the sync to the end of the e2e layer` and `shortcuts: sandbox.sh e2e waits while another checkout holds the sandbox lock`:
  - The `ssh` and `rsync` stubs also append `<their GUEST_LOG line>\t<yes|no>` (`[ -d "$SANDBOX_STATE/lock" ]`) to a second log, `$LOCK_LOG` (added to `sandbox_env`). `GUEST_LOG` lines stay as they are, so the existing order assertions (`startswith`/`endswith`) are untouched.
  - The holding case also asserts that `$SANDBOX_STATE/lock` is gone after exit.
  - The waiting case starts a holder as in task 1 (2 s), runs `sandbox.sh e2e` with `vim.system` in the background, reads `GUEST_LOG` after 1 s (no `rsync` line), then waits for code 0 and asserts the stderr text and the sync → restore → e2e order.
  - Both fail, because `sandbox.sh` takes no lock.
- [x] 2.2 In `tests/sandbox/sandbox.sh`:
  - source `lock.sh`;
  - define `LOCK=$STATE/lock`;
  - in the command dispatch, call `sandbox_lock "$LOCK"` for `up`, `provision`, `down`, `ssh`, and in `e2e()` after the `in_vm` and `E2E=0` exits and before the running check;
  - update the header comment (commands that change the guest are serialized across checkouts).
  - `PROVISION_REV` is unchanged.
- [x] 2.3 All `test_sandbox.lua` cases pass, the earlier "sandbox.sh e2e restores guest state after syncing and before the e2e layer" included. `make quick` is green.

## 3. Load-scaled deadlines

Scenarios: "The load factor is 1 on an idle host", "The load factor is the load per CPU on a busy host", "The stack harness wait stretches with host load", "The stack harness wait keeps its timeout on an idle host", "The smoke startup budget scales with host load only when busy".

- [x] 3.1 Failing tests with those five titles (prefix `shortcuts: `). Pin `vim.uv.loadavg` to `0, 0, 0` in `FOCUSED_PANE` of `test_stack_cli.lua`, so the existing "fails when the zellij session stays gone" and "keeps a zellij CLI retry within the outer wait" cases keep their 2 s bounds whatever the machine's load. That makes the test more deterministic, not weaker. The cases fail, because `H.load_factor` and `tests/smoke/budget.lua` do not exist.
- [x] 3.2 Add `H.load_factor()` to `tests/helpers.lua` (LuaCATS, `max(1, loadavg / available_parallelism)`).
- [x] 3.3 In `tests/shortcuts/stack.lua`, scale the timeout in `M.wait_for` (default and explicit, before `wait_deadline` is set) and `self.cli_timeout or CLI_TIMEOUT_MS` in `Stack:retry_cli` by `H.load_factor()`, read when each wait starts. The clamp to the outer `wait_deadline` stays.
- [x] 3.4 Add `tests/smoke/budget.lua` (`local M = {}`, LuaCATS) with `startup_budget(base_ms)` = `base_ms * H.load_factor()`, rounded. `tests/smoke/run.lua` judges both the median and the fastest-of-9 against it and prints `budget N ms (x<factor> load)` when the factor is above 1.
- [x] 3.5 The five cases and the existing `test_stack_cli.lua` cases pass. `make smoke-startup` passes. `make quick` is green.

## 4. Docs and gate

Scenarios: none (docs and the gate only, so no failing test; tasks 1-3 hold every scenario).

- [x] 4.1 `docs/testing.md`:
  - Sandbox VM: `sandbox.sh` commands that change the guest are serialized by `~/.cache/nvim-e2e-sandbox/lock` (wait message, stale reclaim, `SANDBOX_LOCK_TIMEOUT`).
  - Smoke details: the budget is multiplied by the load factor when the load exceeds the CPU count.
  - stack bullet: deadlines scale the same way.
  - Layout: add `lock.sh` to the `sandbox/` line.
- [ ] 4.2 Manual concurrency check (VM up): run `make e2e` from this worktree and from a second checkout at once. One prints `sandbox: waiting for`, and both pass.
- [ ] 4.3 `make check E2E=1` is green.
