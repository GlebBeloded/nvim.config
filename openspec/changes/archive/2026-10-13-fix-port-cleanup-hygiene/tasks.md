# Tasks

Layers: integration (`tests/integration/nvim-debug-log/`) and unit (`tests/unit/statusline/`), child via `child.start_bare()`. Cases are named `"<capability>: <scenario title>"`.

## 1. Merge and port debug-log pruning (nvim-debug-log)

Scenarios: `logs older than 7 days are deleted`, `other files in the log directory are kept`, plus every existing nvim-debug-log scenario (`Require alone does not log`, `Setup twice logs once`, `Stop ends logging`, `Other redirection survives a flush`, …).

- [x] 1.1 Failing test first:
  - Run `git merge --no-commit loop/cleanup-hygiene`.
  - Resolve `openspec/specs/nvim-debug-log/spec.md` by keeping `auto`'s text plus the branch's "Old log pruning" requirement.
  - Resolve `openspec/specs/statusline/spec.md` by keeping `auto`'s text plus the branch's "LSP progress log size cap" requirement.
  - Resolve `lua/gleb/nvim_debug_log/init.lua` to `auto`'s side.
  - In `tests/integration/nvim-debug-log/test_prune.lua`, change both `child.lua([[require("gleb.nvim_debug_log")]])` calls to `.setup()`.
  - Verify: `make test FILE=tests/integration/nvim-debug-log/test_prune.lua` fails "nvim-debug-log: logs older than 7 days are deleted" (the 8-day-old file survives).
- [x] 1.2 In `lua/gleb/nvim_debug_log/init.lua`:
  - Add a LuaCATS-typed `MAX_AGE_S` and `prune_old_logs(dir, max_age_s)` from the branch.
  - Call it in `M.setup()` right after `vim.fn.mkdir(LOG_DIR, "p")`, before `state.path` is built.
  - Keep the header comment accurate.
  - Verify: `CAPS=nvim-debug-log make test` is all green, including "nvim-debug-log: Require alone does not log".
- [x] 1.3 Apply this change's delta wording (`setup()`) to "Old log pruning" in the archived `openspec/changes/archive/2026-10-13-cleanup-hygiene/specs/nvim-debug-log/spec.md`, and update the Decisions in its `design.md` ("before the session's file is created" → inside `setup()`). Verify: `openspec validate fix-port-cleanup-hygiene` passes.

## 2. LSP progress log cap next to stale-task cleanup (statusline)

Scenarios: `oversized progress log is truncated`, `progress log under the cap is appended`, plus every "LSP progress cleanup" scenario and `progress events are logged`.

- [x] 2.1 Failing test first: with the merge from 1.1 in progress, `lsp_progress.lua` still holds conflict markers. Verify: `make test FILE=tests/unit/statusline/test_lsp_progress_log.lua` fails to load the module.
- [x] 2.2 Resolve the constants conflict in `lua/gleb/statusline/lsp_progress.lua`:
  - Keep `STALE_AFTER_MS`, the `$NVIM_LSP_PROGRESS_LOG` fallback for `LOG_PATH`, and `LOG_MAX_BYTES`.
  - The header keeps both the "never stuck" and the log-cap/override notes.
  - Verify: `CAPS=statusline make test` is green ("statusline: oversized progress log is truncated", "statusline: progress log under the cap is appended", "statusline: stale task is removed", "statusline: progress events are logged").

## 3. Gate

- [x] 3.1 Commit the merge. Verify:
  - `git grep -n '^<<<<<<<'` is empty.
  - `openspec/changes/cleanup-hygiene/` is gone and the archive folder exists.
  - `make trace VERBOSE=1` lists all four cleanup-hygiene scenarios as tested with 0 orphans.
  - `git diff --exit-code tests/screenshots`.
  - `make check E2E=1` is green.
