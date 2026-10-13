# Design

## Context

Root cause (see proposal.md - Why): the module logs through `:redir`, and Neovim has one active
redirection at a time. Starting `:redir => g:other` already ends the module's file redirection;
the next flush then runs `:redir END` (ending the user's redirection) and `:redir >> <log>`
(taking the slot back). No function or event reports whether a redirection is active, so the
module cannot detect a foreign `:redir` and skip the flush. The duplicate timer/autocmd comes from
doing the work at require time with a bare `nvim_create_autocmd`.

`execute()` / `nvim_exec2()` capture output without using the `:redir` slot, so they never
conflicted; only `:redir` itself (typed or `vim.cmd`) does.

## Goals / Non-Goals

**Goals:**
- Log every message to the per-session file without touching the `:redir` slot.
- `setup()` idempotent, `stop()` reverses it; require has no side effect.

**Non-Goals:**
- Changing what is logged, the file path or the flush interval.
- Logging while the user has set their own `'verbosefile'`.

## Decisions

### Logging mechanism

**Proposed A (picked): `'verbosefile'` instead of `:redir`.** `'verbosefile'` receives every
message (not only verbose ones), appends, and is independent of `:redir`. Checked on Neovim 0.12.5
headless: `:echom`, `:echo`, `vim.notify` and `nvim_err_writeln` all land in the file, and a
concurrent `:redir => g:o` kept the lines echoed before and after a flush. Writes are buffered;
setting the option to `""` closes the file and setting it back reopens it in append mode, so the
flush keeps its shape. Cost: Neovim's `verbose_enter()` silences the screen while
`'verbosefile'` is set, so output gated on `'verbose'` goes only to the file. The visible case is
the `Last set from` line of `:verbose map` (the debug step in `docs/workflow.md`, Neovim keys):

Current render, 100x40, Normal mode after `:verbose nmap <C-h>` (bottom 5 rows):

```text
~
:verbose nmap <C-h>
n  <C-H>       * <Lua 398: ~/.local/share/nvim/lazy/smart-splits.nvim/lua/smart-splits/lazy.lua:72>
        Last set from ~/.config/nvim/init.lua (run Nvim with -V1 for more details)
Press ENTER or type command to continue█
```

Proposed A render, 100x40, Normal mode after `:verbose nmap <C-h>` (bottom 5 rows) (the `Last set from` line is in `/tmp/nvim/<ts>_<pid>.txt`):

```text
~
~
:verbose nmap <C-h>
n  <C-H>       * <Lua 398: ~/.local/share/nvim/lazy/smart-splits.nvim/lua/smart-splits/lazy.lua:72>
Press ENTER or type command to continue█
```

Mitigation: `:lua require("gleb.nvim_debug_log").stop()` before `:verbose …` restores the screen
output; the `docs/workflow.md` step gets that note.

**Proposed B: keep `:redir`, pause the flush after a typed `:redir`.** A `CmdlineLeave` handler
parses `getcmdline()`; on `:redir …` it pauses the flush, on `:redir END` it resumes and restarts
the log. Screen output unchanged (Current render stays). Rejected: `vim.cmd("redir …")` and
`nvim_command` fire no cmdline event, so a plugin's redirection is still cut, which fails the
`Other redirection survives a flush` scenario and the proposal's "user (or a plugin)".

**Rejected outright:**
- `vim.ui_attach` with `ext_messages`: takes over message rendering for the whole UI.
- Polling `:messages`: misses `:echo` (no history), breaking `captures :echo from ex command`.
- Wrapping `vim.notify`/`print`: misses Vimscript `:echo`, `:echom` and errors.

A is picked because it is the only option that satisfies every scenario in the spec; its screen
cost is limited to `'verbose'`-gated output and is reversible with `stop()`. The design gate shows
this trade-off; if the user rejects it, B is the fallback with the scenario narrowed to typed
`:redir`.

### Flush without side effects
The flush runs `noautocmd set verbosefile=` then `noautocmd set verbosefile=<path>`, so the
2000 ms tick fires no `OptionSet`. It toggles only while `'verbosefile'` still equals the module's
path; if anything else changed the option, the flush leaves it alone.

### Module shape
`M.setup()` returns early when already started; it creates `/tmp/nvim`, computes the path once,
sets `'verbosefile'`, starts the repeating timer and registers `VimLeavePre` in augroup
`gleb_nvim_debug_log` (`{ clear = true }`) calling `M.stop()`. `M.stop()` stops the timer, deletes
the augroup and resets `'verbosefile'` to `""` when it still holds the module's path, then allows
a later `setup()`. `init.lua` keeps the call first.

## Risks / Trade-offs

- [`'verbose'`-gated output leaves the screen, see Proposed A] → `stop()`, documented next to the
  `:verbose map` debug step; the design gate asks the user.
- [User sets `'verbosefile'` themselves] → the flush stops touching it (path check); the log
  resumes only after `stop()` + `setup()`.
- [Messages since the last flush are lost on a crash] → same as today with `:redir`.
