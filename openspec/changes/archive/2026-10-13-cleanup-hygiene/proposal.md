## Why
Small hygiene items from the former findings list ("Low / hygiene", "Medium") that are still in the code (verified 2026-10-12):
- `lua/gleb/plugins/plugins.lua:24` spells `priorty = 1000`, so lazy.nvim ignores the priority of gruvbox-material (convention rule 2.6).
- `lua/gleb/lsp/init.lua:4` runs `set updatetime=1000`, which overrides `updatetime = 300` from `lua/gleb/options.lua:22` (rule 1.7). The effective value today is 1000.
- Every Neovim start, test children included, writes `/tmp/nvim/<time>_<pid>.txt` (`lua/gleb/nvim_debug_log/init.lua:1-6`), and every `LspProgress` event appends to `/tmp/nvim-lsp-progress.log` (`lua/gleb/statusline/lsp_progress.lua:12,50-67`). Neither is ever cleaned up, so both grow without bound until macOS purges `/tmp`.
- `lua/gleb/lualine.lua:82-89` `inactive_sections` are dead with `laststatus=3` (one global statusline).
- Stale comments (rule 9.3): `lua/gleb/file_tree/init.lua:79` mentions an "Alt+C for AI" map that does not exist; `lua/gleb/git/vscode_diff.lua:7` says "Explorer disabled" above an `explorer` table that configures it; `lua/gleb/lualine.lua:94` says "make bufferline global" above `vim.opt.laststatus = 3`.

Kind: bug

## What Changes
- `plugins.lua:24`: `priorty` -> `priority`.
- Remove `set updatetime=1000` from `lsp/init.lua:4` and set the single value in `options.lua:22`. Keep the effective value 1000 (no behaviour change) and fix the comment; lowering it to 300 is a user decision and out of scope.
- Log cleanup that keeps every spec'd scenario: at startup, `gleb.nvim_debug_log` deletes `/tmp/nvim/<time>_<pid>.txt` files whose `<time>` is more than 7 days old (the current session's file is created after pruning and is never touched), and `gleb.statusline.lsp_progress` empties its log before appending once it exceeds 1 MiB. The log path can be overridden with `$NVIM_LSP_PROGRESS_LOG` so the size-cap test does not wipe the shared `/tmp` log under parallel test workers. The existing nvim-debug-log scenarios (file `<digits>_<pid>.txt` is created, messages land in it, `BEFORE_EXIT` is in the file after exit) and "progress events are logged" still hold. Deleting the log on exit was rejected because the spec reads it after exit.
- Delete the dead `inactive_sections` table from `lualine.lua`.
- Fix the three stale comments above.

## Capabilities
### Modified Capabilities
- `nvim-debug-log`: ADDED requirement "Old log pruning" (logs older than 7 days are deleted at startup).
- `statusline`: ADDED requirement "LSP progress log size cap" (log emptied past 1 MiB; `$NVIM_LSP_PROGRESS_LOG` override).
- The other items (priority typo, `updatetime`, dead `inactive_sections`, comments) change no scenario.

## Impact
- Code: `lua/gleb/plugins/plugins.lua`, `lua/gleb/lsp/init.lua`, `lua/gleb/options.lua`, `lua/gleb/nvim_debug_log/init.lua`, `lua/gleb/statusline/lsp_progress.lua`, `lua/gleb/lualine.lua`, `lua/gleb/file_tree/init.lua`, `lua/gleb/git/vscode_diff.lua`; tests for the two ADDED requirements.
- Plugins: none added, removed or upgraded (gruvbox-material now actually loads with priority 1000)
- Core keymaps: unchanged
- Out of scope:
  - The diff `cond` (`lualine.lua:6-8`, `vim.fn.winwidth(0) > 80`): with a global statusline the full-width bar arguably should use `vim.o.columns`, but the scenario "diff hidden in narrow windows" specifies the current window width, so changing it needs its own change with a spec delta.
  - The `:redir END` flush bug (`fix-debug-log-redir`), the LSP progress timer (`fix-lsp-progress-stuck-task`), the `init.lua:8-9` comments (`fix-mapleader`), other convention cleanups (`cleanup-convention-targets`).
