## Why

Kind: bug

`actions: Plugin-window mappings are action-owned` hangs under load: the runner reports `hung: no progress for 300 s
(waiting for input or a never-met condition?)`, kills the worker, and 90 other cases on that worker are reported "not
run", so one flake turns a whole check red. Earlier runs failed the same case with `mason window did not open`.

## Evidence

- `make check` on auto (round102, 2026-10-18): `FAIL in tests/integration/actions/test_plugin_ownership.lua | actions:
  Plugin-window mappings are action-owned: hung: no progress for 300 s`, followed by 90 `not run: its worker was killed
  after a hung case`
- an earlier gate: `tests/integration/actions/test_plugin_ownership.lua:41: mason window did not open`
- tests/integration/actions/test_plugin_ownership.lua:39-42 (`open_surface`) runs `child.lua(open)` synchronously, so
  an open that blocks the child (a prompt, a plugin waiting for input or the network) blocks the RPC forever; the
  10 s `child.wait` after it never starts

## What Changes

- Open each plugin surface without blocking the child's RPC (schedule it, e.g. `vim.schedule(function() <open> end)`),
  then wait for the buffer with the existing `child.wait`; when it does not appear, fail with the surface's name and
  the child's current mode and messages instead of hanging.
- Find and fix what blocks (probe the surfaces one at a time under `make probe`): a surface that cannot open offline
  in the test environment is opened in a way that does not need the network.

## Impact

- tests/integration/actions/test_plugin_ownership.lua (assertions unchanged)
