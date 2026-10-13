## Why
Under `make check E2E=1` the stack layer fails now and then in its `pre_case` hook at `tests/stack/shortcuts/test_stack.lua:28` with `no client in list-clients`, or with `zellij action failed: There is no active session!`. `make stack` on its own passes. The zellij client stays attached the whole time. One `zellij action` call fails transiently while the zellij server is busy and the CPU is oversubscribed, because zellij 0.45.1 frees each CLI client id twice and a late second removal drops the next connection that reuses the id. The harness treats that one bad answer as fatal (`tests/shortcuts/stack.lua:141-152`). Reproduced at about 1 in 240 calls under redraw plus CPU load, and 0 in 2,300 without that combined load. Full evidence: root-cause.md of run e768bfcf.

Kind: bug

## What Changes
- `Stack:focused_pane()` re-queries `list-clients` until it gets a client row, and fails only after a bounded deadline. It retries both transient answers: exit 1 with `There is no active session!`, and exit 0 with no client row.
- `Stack:zellij(...)` retries an action that fails with `There is no active session!`. zellij exits on that message before it sends the action, so a retry never runs the action twice. Any other failure stays fatal right away.
- Every caller gets this: the stack `pre_case` (`reset`), the stack and e2e cases, and `connect()`.
- Deviation from the bug's acceptance criterion ("wait for the zellij client with a readiness signal"): the client is already attached when the hook runs (`connect()` saw it on `terminal_0`). The failure can hit any CLI call at any time, so a one-time readiness wait would not fix it. Each query instead waits for a valid answer, with no fixed sleep.

## Capabilities
### Modified Capabilities
- `shortcuts`: requirement "Real zellij delivers shortcuts" gains two harness scenarios. A transient zellij CLI failure is retried, and a session that is really gone still fails.

## Impact
- Code: `tests/shortcuts/stack.lua` only. The e2e harness (`tests/e2e/alacritty.lua`) and both test files use it unchanged.
- Tests: new unit cases in `tests/unit/shortcuts/test_stack_cli.lua`, with `zellij` stubbed on `PATH`.
- Plugins: none added, removed or upgraded.
- Core keymaps: unchanged.
- Out of scope: fixing zellij upstream (the double `RemoveClient` in `zellij-server`), retrying `tmux send-keys`, and changing `make check` concurrency.
