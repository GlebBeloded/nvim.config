## Why
The 2000 ms flush timer in `lua/gleb/nvim_debug_log/init.lua:8-15` runs `:redir END` and `:redir >> <log>` unconditionally, so any `:redir` the user (or a plugin) starts is cut off at the next tick. The `VimLeavePre` autocmd (`:17`) has no augroup, so sourcing the module again adds a second autocmd and a second timer. The module returns nothing: requiring it is the side effect, so it can't be stopped or tested in isolation.

Kind: bug

## What Changes
- The module returns a table `M` with `M.setup()` (starts logging; calling it again does not add a second timer or autocmd) and `M.stop()` (stops the timer and ends the log redirection). Requiring it has no side effect.
- `init.lua:4` calls `require("gleb.nvim_debug_log").setup()`, still first.
- The `VimLeavePre` autocmd lives in an augroup created with `{ clear = true }`.
- The flush no longer ends a redirection the module did not start. Design picks the mechanism (e.g. stop flushing while another `:redir` is active, or log through `'verbosefile'` / a message hook instead of `:redir`).
- Tests (`tests/integration/nvim-debug-log/test_debug_log.lua`) call `setup()`.

## Capabilities
### Modified Capabilities
- `nvim-debug-log`: logging starts from `setup()` instead of on require; adds idempotent setup, `stop()`, and "other redirections are kept".

## Impact
- Code: `lua/gleb/nvim_debug_log/init.lua`, `init.lua`, `tests/integration/nvim-debug-log/test_debug_log.lua`.
- Plugins: none added, removed or upgraded.
- Core keymaps: unchanged.
- Out of scope: cleaning up old `/tmp/nvim` logs; the 3000 ms test wait against the 2000 ms flush; log location and file name.
