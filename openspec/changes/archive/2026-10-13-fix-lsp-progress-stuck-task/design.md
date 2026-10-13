# Design

## Context

Root cause (see proposal.md - Why): `active` in `lua/gleb/statusline/lsp_progress.lua` loses an entry
only on `kind == "end"`. A server that crashes, is stopped (`:LspStop`, `:LspRestart`) or drops its
`end` leaves the entry forever; `progress()` keeps rendering it and the 100 ms timer keeps calling
`lualine.refresh()` because it stops only when `active` is empty. Nothing handles `VimLeavePre`.

Neovim facts that shape the fix (runtime 0.12, `vim/lsp/client.lua`, `vim/lsp.lua`):
- `Client:_on_detach(bufnr)` fires `LspDetach` with `data.client_id` once per attached buffer. It runs
  on client exit (`_on_exit`), on `buf_detach_client`, and on buffer unload. While the event fires,
  `bufnr` is still in `client.attached_buffers`.
- A client with no attached buffer emits no `LspDetach` when it dies.
- Unit tests fire `LspProgress` for `client_id = 1` with no real client, so
  `vim.lsp.get_client_by_id(1)` is `nil` there.

## Goals / Non-Goals

**Goals:**
- Tasks cannot outlive their client or a silent server; the refresh timer cannot outlive the tasks
  or Neovim.

**Non-Goals:**
- Polling `vim.lsp.get_clients()` on every tick, changing the log, aliases or the 500 ms delay.

## Decisions

1. **Detach drops a client's tasks only when the client is really leaving.** On `LspDetach`, drop
   every key prefixed `<client_id>:` when `get_client_by_id(id)` is `nil`, `client:is_stopped()`, or
   `args.buf` is the only key left in `client.attached_buffers`. Alternative: drop on every detach -
   rejected, closing one buffer would hide the progress of a server still indexing others.
   Alternative: check client liveness on each timer tick - rejected, it duplicates `LspDetach` and
   would drop the fake client of every existing unit test.
2. **Stale timeout is the backstop.** Each task stores `seen_ms`, set on `begin` and `report`. A
   `prune_stale()` drops tasks with `now - seen_ms > STALE_AFTER_MS` (60 000). It runs at the start
   of `progress()` and in the timer tick, so cleanup happens even when lualine does not redraw. It
   covers servers that never send `end` and clients that die with no attached buffer.
   `start_ms` stays for the 500 ms show delay.
3. **Clock stays `vim.uv.hrtime`**, read at call time through the `uv` table, so tests advance time
   by replacing `vim.uv.hrtime` in the child instead of sleeping 60 s. No test-only API.
4. **Timer lifecycle in two named functions.** `ensure_timer()` creates the timer into a local
   (`local t = assert(uv.new_timer())`), starts it, then stores it - this removes the
   `need-check-nil` at `:75`. `stop_timer()` stops and closes it and clears the upvalue; it is
   called from the tick when `active` is empty and from a `VimLeavePre` autocmd in the existing
   `gleb_lsp_progress` augroup (rule 6.5, rule 7). The tick body becomes a named function.

### Renders

Current render - 80x1, normal mode, `lua/gleb/statusline/lsp_progress.lua`, lua_ls stopped with
`:LspStop` while indexing (excerpt: statusline row). The task never ends; the spinner keeps turning.

```text
 NORMAL                                    ⠹ indexing workspace 40%  0  0   lua 
```

Proposed render - same state. The task is dropped on `LspDetach` of the last buffer; the statusline
matches the idle reference screenshot.

```text
 NORMAL                                                           0  0   lua 
```

Colors are unchanged: the progress component uses the existing lualine_x section groups.

## Risks / Trade-offs

- [A server silent for over 60 s mid-task loses its entry for good: a later `report` for an unknown
  key is ignored] → accepted; servers report far more often, and a minute without updates reads as
  stuck anyway.
- [Faking `vim.uv.hrtime` also shifts the spinner frame] → stale tests assert entry count or `""`,
  not the frame.
