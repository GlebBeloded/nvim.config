## Why
Three gaps let a save clobber a good session. `nvim file` skips restore (`session/init.lua:24-26`) but the `BufWritePost`/`VimLeavePre` save still runs (`:47-50`), overwriting the pane session with that one file. A pane that quits with no file buffers is saved as `"buffers": []`, and the cwd fallback can then restore nothing. auto-save's `condition` checks only `buftype` and `filetype` (`plugins/plugins.lua:271-274`), so typing in an `:enew` buffer sets `v:errmsg` to `E32: No file name` after the debounce.

Kind: bug

## What Changes
- Session saves (on `BufWritePost` and `VimLeavePre`) run only when Neovim was started with no file arguments.
- Skip the save when no listed buffer has a name and an empty `buftype`; the previously saved session is kept.
- auto-save `condition` also requires a non-empty buffer name. Optionally move the auto-save config into `lua/gleb/session/` (the spec puts it in this capability).

## Capabilities
### Modified Capabilities
- `session`: Save on write and exit (no save for `nvim file`, no empty sessions), Auto-save modified buffers (unnamed buffers skipped).

## Impact
- Code: `lua/gleb/session/init.lua`, `lua/gleb/plugins/plugins.lua` (auto-save spec)
- Plugins: none added, removed or upgraded
- Core keymaps: unchanged
- Out of scope: fallback matching and ordering (fix-session-fallback-match); a session save on every auto-save write; resession's own autosave (stays disabled).
