## Context
See proposal.md - Why. Root causes:
- `lua/gleb/session/init.lua` registers `save` on `BufWritePost`/`VimLeavePre` with no guard; the `argc(-1) ~= 0` check exists only in `restore`. `nvim b.txt` therefore saves a one-file layout over the pane key.
- `save` calls `resession.save` whatever the buffer list holds; resession writes `"buffers": []` when no listed buffer is a file, and `key.resolve` happily returns that session later.
- auto-save.nvim checks only `modifiable` and our `condition`, then runs `silent! write` on the buffer. For an unnamed buffer `:write` fails with `E32: No file name`; `silent!` hides the message but still sets `v:errmsg`.

No visible UI: nothing on screen changes, so no renders.

## Goals / Non-Goals
**Goals:**
- One `should_save()` predicate decides every session save.
- auto-save skips unnamed buffers before calling `:write`.

**Non-Goals:**
- Moving the auto-save spec out of `plugins.lua` (the proposal's optional step). It would change plugin wiring for no behavioural gain; it can be its own cleanup change.
- Deleting or repairing session files that are already empty.

## Decisions
- **Capture "started bare" once at startup.** Read `vim.fn.argc(-1) == 0` when `init.lua` loads (before `VimEnter`) into a module local used by both `restore` and the save guard. Alternative: call `argc(-1)` at save time; rejected because `:args`/`:argadd` later in the session change the arglist, and the spec says "started with".
- **Named predicates, no anonymous logic.** `has_file_buffer()` returns true when some `getbufinfo({ buflisted = 1 })` entry has a non-empty name and `buftype == ""`; `should_save()` combines it with the startup flag. `save` returns early when `should_save()` is false. Alternative: filter inside resession via its `buf_filter` option; rejected because it only drops buffers and still writes an empty session, which is exactly the bug.
- **auto-save condition: add `vim.api.nvim_buf_get_name(buf) ~= ""`.** Keep it in the existing `condition` (plugin option, no custom autocmd). Extract the function to a named local (`should_autosave`) in the spec to satisfy the no-long-anonymous-function rule.

## Risks / Trade-offs
- [A pane opened as `nvim file` never updates its session, even after `:e other`] → intended per proposal; a bare `nvim` in that pane still restores the last bare session.
- [`:enew` text is never auto-saved] → it has no path to save to; the user writes it with `:w name`.
- [Integration tests that restart into `nvim <file>` then `child.stop()` used to rewrite the session on `VimLeavePre`] → now they do not; no existing assertion depends on it.

## Migration Plan
None. Rollback is reverting the commit.
