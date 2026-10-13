# Tasks

**Goal:** stack and e2e cases no longer fail on one transient `zellij action` answer; `make check E2E=1` passes 5 times in a row.

**Spec:** `specs/shortcuts/spec.md` (requirement "Real zellij delivers shortcuts"). No design.md: no visible UI and no structural change.

## Global Constraints

- Harness only (`tests/shortcuts/stack.lua`). No stack or e2e case is weakened, and no case gets an extra `pcall` or sleep.
- Retry by polling for a valid answer with `vim.wait` and a bounded deadline. No fixed sleep.
- Retry only `There is no active session!` (and, for `list-clients`, a missing client row). Any other `zellij action` failure stays fatal on the first attempt.
- LuaCATS types on new functions; small named functions, no long anonymous function.
- The unit layer follows `tests/unit/shortcuts/test_sandbox.lua`: bare child, shell stubs written by the child, `vim.system` run in the child.

## Review Focus

- `Stack:zellij` passes `self.env` to `vim.system`, so the stub dir must be first on `self.env.PATH`, not only on the child's `$PATH`.
- `M.wait_for` asserts with a fixed message; the timeout error must carry the last zellij stderr (`There is no active session!`), so the retry cannot reuse `wait_for`'s message as is.
- `connect()` already polls `focused_pane()` inside `M.wait_for`: the nested deadline must not stretch startup failures far past today's 10 s.
- `pre_case` (`tests/stack/shortcuts/test_stack.lua:28`) and `tests/e2e/alacritty.lua` keep calling the same methods; no caller changes.

---

## 1. Retry transient zellij CLI failures

Scenarios: "shortcuts: The stack harness retries a transient zellij CLI failure", "shortcuts: The stack harness fails when the zellij session stays gone"

**Files:** `openspec/specs/shortcuts/spec.md`, `tests/unit/shortcuts/test_stack_cli.lua` (new), `tests/shortcuts/stack.lua`

- [x] 1.1 **Sync spec.** Apply the delta of `specs/shortcuts/spec.md` to `openspec/specs/shortcuts/spec.md` (requirement text plus the two scenarios), so `make trace` knows the new titles.
- [x] 1.2 **Failing test.** Create `tests/unit/shortcuts/test_stack_cli.lua` with `H.child_set(child, child.start_bare)`. A `zellij` shell stub, written into a temp dir by the child and chmod 755, appends one line per call to a count file and answers by call number from `$ZELLIJ_STUB_MODE`:
  - `flaky`: call 1 prints `There is no active session!` to stderr and exits 1; call 2 prints only the header `CLIENT_ID ZELLIJ_PANE_ID RUNNING_COMMAND`; call 3+ prints the header and `1 terminal_0 nvim`.
  - `gone`: every call prints `There is no active session!` to stderr and exits 1.

  In the child, `require("tests.shortcuts.stack")` and build a Stack with `setmetatable({ session = "s", env = { PATH = stub_dir .. ":" .. vim.env.PATH, ZELLIJ_STUB_MODE = mode, ... }, cli_timeout = ms }, M.Stack)` (no `start()`).
  - `T["shortcuts: The stack harness retries a transient zellij CLI failure"]`: `focused_pane()` returns `"terminal_0"`; the count file has 3 lines.
  - `T["shortcuts: The stack harness fails when the zellij session stays gone"]`: with `cli_timeout = 300`, `pcall(focused_pane)` is false, the error contains `There is no active session!`, and it returns in under 2 s.

  Run `make test FILE=tests/unit/shortcuts/test_stack_cli.lua` → FAIL (`M.Stack` is nil). Temporarily expose only `M.Stack = Stack` and re-run → the retry case FAILS with `zellij action failed: There is no active session!`.
- [x] 1.3 **Implement** in `tests/shortcuts/stack.lua`:
  - `M.Stack = Stack` next to `M.run, M.write`, and a `---@field cli_timeout integer?` on `shortcuts.Stack` (ms, default 5000 as a named constant `CLI_TIMEOUT_MS`).
  - A named `---@param result vim.SystemCompleted ---@return boolean local function no_session(result)`: exit non-zero and stderr contains `There is no active session!` (plain find).
  - A named helper `Stack:retry_cli(attempt)` (`attempt: fun(): boolean, string`, returning done plus the value or last error text) that loops with `vim.wait(self.cli_timeout or CLI_TIMEOUT_MS, ..., 50)` and on timeout raises `"stack: zellij CLI kept failing: " .. last`.
  - `Stack:zellij(...)` retries while `no_session(result)`; any other non-zero exit asserts at once with today's `zellij action failed:` message.
  - `Stack:focused_pane()` retries the whole `list-clients` query while the second line has no client row.

  Run `make test FILE=tests/unit/shortcuts/test_stack_cli.lua` → PASS; `make stack` → PASS; `make trace` → both titles `tested`, no orphans; `make lint` and `make types` → green.
- [x] 1.4 **Commit** `fix(stack): retry transient zellij CLI failures`.

## 2. Gate

- [ ] 2.1 `make check` green.
- [ ] 2.2 `make check E2E=1` green 5 times in a row (the bug's acceptance criterion). Record the 5 status lines in the PR notes.
