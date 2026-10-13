# Design

## Context

See proposal.md (Why) for the items. All were re-checked against the code on 2026-10-12 and still hold. Root causes:
- `priorty`: a typo, so lazy.nvim treats it as an unknown spec key and gives gruvbox-material the default start priority of 50.
- `updatetime`: `init.lua` requires `gleb.options` (300) before `gleb.lsp`, whose `set updatetime=1000` wins. Its only consumer is CursorHold (`lsp/lightbulb.lua`).
- Unbounded logs: neither module ever removes or limits what it writes.
- `inactive_sections`: with `laststatus=3` only the current window's statusline is drawn. The table also matches lualine's defaults, so removing it changes nothing.

No screen output changes, so this design has no renders.

## Goals / Non-Goals

**Goals:**
- Bound `/tmp/nvim` and `/tmp/nvim-lsp-progress.log` without breaking any existing scenario.
- Keep startup within the smoke budget: pruning runs first in `init.lua`, on the startup path.
- Tests never delete or truncate the user's real logs.

**Non-Goals:**
- Changing the effective `updatetime` (stays 1000).
- Any lazy-loading or config change to gruvbox-material beyond the typo fix.

## Decisions

- **Debug log age comes from the file name, not mtime.** Files are named `<os.time()>_<pid>.txt`, so the start time is in the name. Pruning lists `/tmp/nvim` (`vim.fs.dir`), matches `^(%d+)_%d+%.txt$` and removes files older than 7 days with `os.remove`. No `stat` per file, it is deterministic in tests (just create files with old names), and files of other formats are never touched. Rejected: mtime-based age, which needs a stat per file and `fs_utime` in tests. Also rejected: deleting on `VimLeavePre`, because the "Log finalized on exit" scenario reads the file after exit.
- **Pruning runs synchronously before the session's file is created.** It does a single directory listing, so it costs well under 1 ms even with hundreds of files. A deferred prune would complicate the tests without a measurable gain. Pruning first also means the current file can never be removed (its timestamp is now anyway).
- **Progress log: size check before each append, empty the file past 1 MiB.** `log()` calls `uv.fs_stat` on the path and opens the file with `"w"` instead of `"a"` when it is larger than 1048576 bytes. Progress events arrive at most a few per second, so one stat per event is negligible. Rejected: checking only at module load, because one long session could still grow the log without bound. Also rejected: rotating to `.log.1`, which is extra state for a debug aid that only needs `tail -f` and `grep`.
- **`$NVIM_LSP_PROGRESS_LOG` overrides the path, read once at module load.** `make test` shards cases over parallel workers that share `/tmp/nvim-lsp-progress.log`. A cap test that writes 1 MiB there and truncates it would race with "statusline: progress events are logged" in another worker and wipe that worker's line. With the override, the cap tests use a private temp file. Rejected: a module-level test hook such as `M._log_path`, which would make tests depend on an internal field. Since an env var is visible behaviour, it is in the spec.
- **`updatetime` set once, in `options.lua`, to 1000.** The comment explains that it drives CursorHold (lightbulb) and swap writes. Nothing else changes.
- **Pure deletions/renames for the rest:** `priority = 1000`, drop `inactive_sections`, and rewrite the three stale comments to describe the code below them. The neo-tree commit comment loses "(Alt+C for AI)", the codediff comment describes the explorer that is configured, and the lualine comment says "global statusline (one for all windows)".

## Risks / Trade-offs

- [gruvbox-material now loads before the other start plugins] → It only ships `colors/` and `autoload/`, and the colorscheme is still applied by `gleb.colors`. Smoke and screen tests confirm that startup and the statusline screenshots are unchanged.
- [Pruning deletes the user's own old logs] → This is the intent. 7 days covers any session someone would still look at.
- [Pruning tests create files in the real `/tmp/nvim`] → They use unused pids (e.g. > 4·10⁹) so the harness's by-pid cleanup and real sessions never collide, and each case removes the files it created that survived.
- [Conflict with queued `fix-debug-log-redir`, which moves logging behind `setup()`] → Pruning belongs to log start. Whichever change lands second calls the prune from `setup()` and updates the WHEN of the two pruning scenarios to `setup()`, the same way that change rewrites the existing scenarios.
- [Conflict with `fix-lsp-progress-stuck-task` in `lsp_progress.lua`] → It touches the timer and task table, not `log()`. A textual merge is enough.

## Migration Plan

None. On the first start after merge, all debug logs older than 7 days are deleted at once. Roll back by reverting the merge commit.
