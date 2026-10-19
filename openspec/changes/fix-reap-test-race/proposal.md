## Why

Kind: bug

`actions: Plugin-window mappings are action-owned | reaps a blocked surface's shell-owned descendant`
(`tests/integration/actions/test_plugin_ownership.lua`, added by fix-differ-surface-stall) fails under load in most gates
since it shipped (runs d79215f6 check-1, ff1671cf check-3, 2026-10-19, load 35–48):

```
FAIL in tests/integration/actions/test_plugin_ownership.lua | actions: Plugin-window mappings are action-owned | reaps a blocked surface's shell-owned descendant:
  Left:  true
  Right: false
    tests/integration/actions/test_plugin_ownership.lua:188
```

Line 184 probes `vim.uv.kill(sleep_pid, 0)` right after `stop_blocked_child` sends SIGKILL: the killed `sleep` (re-parented
to launchd once its `sh` dies) can still exist for a moment, and a zombie answers signal 0, so the probe races the kill.

## What Changes

- Wait for the process to be gone instead of probing once: poll `vim.uv.kill(sleep_pid, 0) ~= 0` (or `ps -p`) up to
  2000 ms × `H.load_factor()`, then assert it is gone; keep the cleanup kill if it is still alive at the end.
- The case still asserts that the descendant is killed (no weaker check): it fails if the process outlives the wait.

## Impact

- `tests/integration/actions/test_plugin_ownership.lua` (the reaping case only).
