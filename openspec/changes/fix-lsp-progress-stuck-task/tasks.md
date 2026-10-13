# Tasks

All tests are unit cases in `tests/unit/statusline/test_lsp_progress.lua` (bare child, lualine stubbed
by the existing `start()`); run them with `make test FILE=tests/unit/statusline/test_lsp_progress.lua`
and `make quick`. Code changes only touch `lua/gleb/statusline/lsp_progress.lua`. No plugin added.

## 1. Drop tasks of a leaving client

Scenarios: "detached client tasks are removed", "detach keeps tasks of a client still attached elsewhere".

- [x] 1.1 Add a `detach(buf)` test helper that runs `nvim_exec_autocmds("LspDetach", { buffer = buf, data = { client_id = 1 } })` in the child (create buffer 2 with `nvim_create_buf` when needed)
- [x] 1.2 Add failing case "statusline: detached client tasks are removed": `fire` begin, `detach(1)` (no stub, `get_client_by_id(1)` is `nil` in the bare child), `eq(progress_after_delay(), "")`; verify it fails (task still shown)
- [x] 1.3 Add case "statusline: detach keeps tasks of a client still attached elsewhere": stub `vim.lsp.get_client_by_id` in the child to return `{ name = "fake", attached_buffers = { [1] = true, [2] = true }, is_stopped = function() return false end }`, `fire` begin, `detach(1)`, `expect_entry(progress_after_delay(), …)`; it passes today and guards decision 1 against "drop on every detach"
- [x] 1.4 Add a named `on_detach(args)` and a `drop_client(client_id)` (removes keys prefixed `<client_id>:`), plus a `client_leaving(client, buf)` predicate: client `nil`, `client:is_stopped()`, or `buf` is the only key in `client.attached_buffers` (design decision 1); register `LspDetach` in the existing `gleb_lsp_progress` augroup (store the augroup id in a local, rule 7.1)
- [x] 1.5 Verify both cases and all existing `statusline:` progress cases pass

## 2. Stale task timeout

Scenarios: "stale task is removed", "report keeps a task fresh".

- [ ] 2.1 Add an `advance_clock(ms)` test helper that replaces `vim.uv.hrtime` in the child with a wrapper adding a cumulative offset of `ms * 1e6` ns to the real clock (design decision 3; no sleeping 60 s, no test-only API)
- [ ] 2.2 Add failing case "statusline: stale task is removed": `fire` begin, `advance_clock(61000)`, `eq(child.lua_get("Progress.progress()"), "")`; verify it fails (task shown, since it is also past the 500 ms delay)
- [ ] 2.3 Add case "statusline: report keeps a task fresh": `fire` begin, `advance_clock(40000)`, `fire` report, `advance_clock(40000)`, assert one entry (`expect_entry`, label only; the frame shifts with the clock); it passes today and guards against pruning by `start_ms`
- [ ] 2.4 Add `STALE_AFTER_MS = 60000` at the top (rule 4.3) and document it in the header comment (rule 9.1); store `seen_ms` on `begin` and refresh it on `report`; update the `active` comment / add a `---@class` for the task entry (rule 5.2); add `prune_stale()` and call it at the start of `M.progress()` and in the timer tick (design decision 2)
- [ ] 2.5 Verify both cases and all task-1 and existing cases pass

## 3. Refresh timer lifecycle

Scenarios: "refresh timer stops when idle", "refresh timer stops on exit".

- [ ] 3.1 Add a `count_refreshes()` test helper that replaces `package.loaded.lualine.refresh` in the child with a counter (`Refreshes = Refreshes + 1`) and a `refreshes()` getter
- [ ] 3.2 Add failing case "statusline: refresh timer stops on exit": `count_refreshes()`, `fire` begin, wait ~150 ms, `nvim_exec_autocmds("VimLeavePre", {})`, read the count, wait 300 ms, `eq` the count unchanged; verify it fails (timer keeps ticking)
- [ ] 3.3 Add case "statusline: refresh timer stops when idle": `count_refreshes()`, `fire` begin, `fire` end, wait ~150 ms for the tick that sees `active` empty, read the count, wait 300 ms, `eq` unchanged; it passes today and guards the idle stop through the refactor
- [ ] 3.4 Refactor into `ensure_timer()` (creates into a local `local t = assert(uv.new_timer())`, starts it, then assigns the upvalue), a named `tick()` (prune, refresh, stop when `active` is empty) and `stop_timer()` (stop, close, clear the upvalue; no-op when there is no timer); register `VimLeavePre` → `stop_timer` in `gleb_lsp_progress` (design decision 4, rules 6.5, 7.3)
- [ ] 3.5 Verify both cases pass, then confirm the `need-check-nil` at `lsp_progress.lua:75` is gone: `lua-language-server --check lua/gleb/statusline --configpath="$PWD/.luarc.jsonc" --checklevel=Information` reports no `need-check-nil` for this file (`.luarc.jsonc` keeps it at Information; restoring the severity is `fix-type-check-baseline`'s job, do not change it here)

## 4. Integration

Scenarios: none new; regression of "statusline matches reference screenshot".

- [ ] 4.1 Run `make trace` and verify the six new scenarios show as tested with no orphans
- [ ] 4.2 Run `make check` and verify it is green, including `make types` and the unchanged screenshot case
