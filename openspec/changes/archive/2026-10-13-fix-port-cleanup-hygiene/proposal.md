## Why
`cleanup-hygiene` was approved and archived on its branch, but `loop/cleanup-hygiene` conflicts with `auto` and was never merged, so none of its fixes are live. Since the branch forked, `fix-debug-log-redir` turned `gleb.nvim_debug_log` into a `setup()`/`stop()` module with no side effect on require. The branch's old-log pruning runs on require, so after a plain merge its scenario "logs older than 7 days are deleted" fails. Root cause: `artifacts/runs/3c258932-69cc-42ad-a002-008ab40c221b/root-cause.md`.

Kind: bug

## What Changes
- Merge `loop/cleanup-hygiene` into this change's branch. Resolve the four conflicts by keeping both sides:
  - `lua/gleb/statusline/lsp_progress.lua`: keep `auto`'s `STALE_AFTER_MS` and stale-task comment, plus the branch's `$NVIM_LSP_PROGRESS_LOG` fallback and `LOG_MAX_BYTES`.
  - `lua/gleb/nvim_debug_log/init.lua`: keep `auto`'s module and run the branch's pruning inside `M.setup()`, after the directory is created and before the session file path is built.
  - `openspec/specs/nvim-debug-log/spec.md` and `openspec/specs/statusline/spec.md`: keep every requirement and scenario from both sides.
- The pruning test `tests/integration/nvim-debug-log/test_prune.lua` starts the log with `setup()` instead of a bare require. Its fixtures and assertions do not change.
- Archive bookkeeping: the merge brings in `openspec/changes/archive/2026-10-13-cleanup-hygiene/` and removes the stale `openspec/changes/cleanup-hygiene/`. Update the archived design to say pruning runs in `setup()`.
- Everything else from the branch merges unchanged: `priority` typo, `updatetime` set once in `options.lua` to 1000 with lightbulb's override disabled, dead `inactive_sections`, stale comments, LSP progress log cap.
- `cleanup-hygiene`'s proposal has no `## Decision` section. Its What Changes still bind: `updatetime` stays 1000, 7-day pruning by file-name time, 1 MiB cap with env override, no delete on exit.

## Capabilities
### Modified Capabilities
- `nvim-debug-log`: MODIFIED requirement "Old log pruning". Pruning runs when `setup()` starts the log, not on require, consistent with "Require alone does not log".
- `statusline`: no delta. "LSP progress log size cap" and "LSP progress cleanup" are merged side by side unchanged.

## Impact
- Code: everything in `cleanup-hygiene`'s Impact list; `nvim_debug_log/init.lua` and `lsp_progress.lua` change by hand-resolved merge.
- Tests: `test_prune.lua` (startup call only), `test_lsp_progress_log.lua` merged as is. No test or scenario is removed or weakened.
- Plugins: none added, removed or upgraded.
- Core keymaps: unchanged.
- Out of scope:
  - New behaviour beyond `cleanup-hygiene`.
  - Lowering `updatetime` to 300.
  - The lualine diff `cond` width.
  - `cleanup-convention-targets` and `cleanup-keymaps`.
