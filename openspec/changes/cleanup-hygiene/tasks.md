# Tasks

## 1. Debug log pruning (nvim-debug-log)

Scenarios: "logs older than 7 days are deleted", "other files in the log directory are kept".

- [x] 1.1 Create `tests/integration/nvim-debug-log/test_prune.lua` (same layer as the existing nvim-debug-log cases; the set in `test_debug_log.lua` requires the module in `pre_case`, before fixtures could exist). `H.child_set` with a `start` that only calls `child.start_bare()`. Add the failing cases `"nvim-debug-log: logs older than 7 days are deleted"` and `"nvim-debug-log: other files in the log directory are kept"`: each creates its fixtures in `/tmp/nvim` with `vim.fn.mkdir(…, "p")` + `vim.fn.writefile`, using unused pids (> 4·10⁹, distinct per case so parallel workers never share a file) and ages `os.time() - 8 * 86400` / `- 1 * 86400`; then `child.lua([[require("gleb.nvim_debug_log")]])` and asserts with `vim.fn.filereadable`. Cleanup in a `finally`-style `pcall` wrapper: `H.delete_debug_log(<fake pid>)` for `.txt` fixtures and `vim.fn.delete` for the others. Run `make test FILE=tests/integration/nvim-debug-log/test_prune.lua`: the first case fails (8-day-old file still exists), the second passes already (guard against over-eager pruning).
- [x] 1.2 In `lua/gleb/nvim_debug_log/init.lua`, add `---@param dir string` `---@param max_age_s integer` `local function prune_old_logs(dir, max_age_s)`: iterate `vim.fs.dir(dir)`, keep only `type == "file"` names matching `^(%d+)_%d+%.txt$`, `os.remove(vim.fs.joinpath(dir, name))` when `os.time() - tonumber(time) > max_age_s`. Hoist `"/tmp/nvim"` and `7 * 24 * 60 * 60` into named locals, call the prune right after `mkdir` and before `path` is built. Verify: `make test FILE=tests/integration/nvim-debug-log/test_prune.lua` and `CAPS=nvim-debug-log make test` all green.

## 2. LSP progress log size cap (statusline)

Scenarios: "oversized progress log is truncated", "progress log under the cap is appended".

- [x] 2.1 Create `tests/unit/statusline/test_lsp_progress_log.lua` (the set in `test_lsp_progress.lua` requires the module in `pre_case`, before the env var could be set). Its `start` does `child.start_bare()` and stubs `package.loaded.lualine` like the existing file, without requiring the module. Each case writes its fixture to a `vim.fn.tempname()` file (1048577 bytes via `writefile({ string.rep("x", 1048576), "" }, path, "b")`, checked with `fs_stat`, or the single line `KEEP`), runs `child.lua([[vim.env.NVIM_LSP_PROGRESS_LOG = ...; require("gleb.statusline.lsp_progress")]], { path })`, fires a `begin` event through `nvim_exec_autocmds("LspProgress", …)` with a unique title, and asserts: `"statusline: oversized progress log is truncated"` → `vim.uv.fs_stat(path).size < 1048576` and a line contains the title; `"statusline: progress log under the cap is appended"` → `readfile(path)` is `{ "KEEP", <line with the title> }`. Delete the temp file at the end. Run the file: both fail (the module ignores the env var and writes to `/tmp/nvim-lsp-progress.log`).
- [x] 2.2 In `lua/gleb/statusline/lsp_progress.lua`: `local LOG_PATH = vim.env.NVIM_LSP_PROGRESS_LOG` falling back to `"/tmp/nvim-lsp-progress.log"` when unset or `""`; `local LOG_MAX_BYTES = 1024 * 1024`. Add `---@return "a"|"w"` `local function log_mode()` that returns `"w"` when `uv.fs_stat(LOG_PATH)` reports `size > LOG_MAX_BYTES`, else `"a"`; `log()` opens with `io.open(LOG_PATH, log_mode())`. Update the header comment (cap, `$NVIM_LSP_PROGRESS_LOG` override). Verify: `CAPS=statusline make test` green, including "statusline: progress events are logged".

## 3. Hygiene fixes without scenarios

No scenario is added or changed, so there is no failing test to write first (a test without a scenario would be a `make trace` orphan). Each step is guarded by existing layers.

- [x] 3.1 `lua/gleb/plugins/plugins.lua:24`: `priorty` → `priority`. Verify: `make smoke` green and `make test-screen` passes with the screenshots unchanged (`git diff --exit-code tests/screenshots`).
- [x] 3.2 Delete `vim.cmd([[ set updatetime=1000 ]])` from `lua/gleb/lsp/init.lua:4`. In `lua/gleb/options.lua:22` set `updatetime = 1000` with the comment "ms of idle before CursorHold fires (code-action lightbulb)" (`swapfile = false`, so it does not drive swap writes; the design's mention of swap is moot). Verify: a headless start of this checkout's config (sandboxed like the tests: `XDG_CONFIG_HOME` pointing at a temp dir whose `nvim` links here) prints `updatetime=1000` for `:set updatetime?`, and `make smoke` is green. Note: `nvim-lightbulb`'s `setup()` sets `updatetime=200` (its `autocmd.updatetime` default), which the removed line used to override; `lsp/lightbulb.lua` now passes `autocmd.updatetime = -1` so the value from `options.lua` holds.
- [x] 3.3 `lua/gleb/lualine.lua`: delete the `inactive_sections` table (82-89) and replace the comment above `vim.opt.laststatus = 3` with "global statusline (one for all windows); must be after lualine setup". Verify: `CAPS=statusline make test-integration` and `make test-screen` pass with screenshots unchanged.
- [ ] 3.4 Stale comments: `lua/gleb/file_tree/init.lua:79` → "Git status: commit with floating input" (drop "Alt+C for AI"); `lua/gleb/git/vscode_diff.lua:7` → describe the configured explorer (left tree panel, 35 columns). Verify: `make lint` passes.

## 4. Gate

- [ ] 4.1 Run `make check`. Verify it is green and `make trace VERBOSE=1` lists the four new scenarios as tested, with no orphans.
