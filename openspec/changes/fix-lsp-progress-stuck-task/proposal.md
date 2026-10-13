## Why
`lua/gleb/statusline/lsp_progress.lua` drops a task only on its `end` event (`:102-103`). When a server crashes, detaches or never sends `end`, the task spins in the statusline forever and the 100 ms refresh timer (`:70-87`) never stops, because it stops only when `active` is empty. Nothing stops the timer on exit either (convention rule 6.5). LuaLS also reports `need-check-nil` on `timer:start` (`:75`, `timer` is an upvalue that LuaLS treats as possibly nil).

Kind: bug

## What Changes
- Drop a client's tasks on `LspDetach` when the client is gone, `is_stopped()`, or the detaching buffer is its last one (`LspDetach` also fires per buffer on unload, so a running client keeps its tasks).
- Drop a task that has had no `begin`/`report` event for `STALE_AFTER_MS` (60 s), so a server that never sends `end` cannot spin forever.
- Stop and close the refresh timer on `VimLeavePre`, and keep stopping it once no task is left.
- Use a local for the new timer in `ensure_timer` so the `need-check-nil` hit at `:75` goes away (counted in `fix-type-check-baseline`).
- Dropped from the original finding: `string.format("%d", pct)` does not error on fractional percentages under LuaJIT (verified: `string.format("%d%%", 12.5)` returns `12%`), so no change there.

## Capabilities
### Modified Capabilities
- `statusline`: new requirement "LSP progress cleanup" (tasks of detached/stopped clients and stale tasks are removed; the refresh timer stops when idle and on exit). "Delayed LSP progress" is unchanged.

## Impact
- Code: `lua/gleb/statusline/lsp_progress.lua`; new unit tests in `tests/unit/statusline/`.
- Plugins: none added, removed or upgraded
- Core keymaps: unchanged
- Out of scope: the progress log file (`cleanup-hygiene`), alias list, labels and the 500 ms show delay.
