## 1. Keep warmed real-config startup within the snappy budget
Scenarios: `plugins: Warm real-config startup stays within budget`
- [x] 1.1 Write the test `plugins: Warm real-config startup stays within budget` in `tests/integration/plugins/test_startup.lua`, driving the standard isolated full-config startup with populated plugin data; set the 120 ms base budget, capture the current baseline, and see it fail
- [x] 1.2 Enable `vim.loader` before the first custom require, replace eager plugin and feature loading with precise existing command, event, filetype, and action triggers, and keep startup-critical registration plus action IDs synchronous
- [x] 1.3 Run `make test FILE=tests/integration/plugins/test_startup.lua CASE="Warm real-config startup stays within budget"` and see it pass
- [x] 1.4 Set `STARTUP_BUDGET_MS` in `tests/smoke/run.lua` to 120, run `make smoke-startup`, and see the warmed real config pass without startup errors
- [x] 1.5 Run `make check` to verify every existing feature scenario still passes through its real entry point

## Agent decisions

- Register language facet validation synchronously in a lightweight module so deferred feature implementations keep the existing startup validation contract.
- Use `BufReadPre` for file-aware setup that must register `FileType` behavior before the opened buffer detects its type.
- Install a synchronous `vim.ui.select` wrapper and action callbacks that load their implementation at the first real invocation.
- Keep smart-splits synchronous because core mappings are contractually the plugin's exact callback functions.
- Load LSP setup on `VeryLazy` as well as file events so its public server configurations remain available before the first edit.
- Register diff highlight ownership synchronously because colorscheme reloads expose those groups even before a diff view opens.
- Load Treesitter setup on `VeryLazy` as well as file events so parser availability checks remain initialized before the first edit.
- Preserve an already selected file-tree settings path when the first action initializes the deferred view.
- Register file-tree highlight ownership synchronously while leaving its model, filesystem, and view setup action-triggered.
- Keep sandbox Treesitter validation synchronous because headless parser-isolation checks intentionally have no UI or file event.
- Initialize the shared picker from direct text-input actions so those entry points do not depend on an earlier picker action.
- Initialize shared picker highlights when the references view first opens because it owns that frame palette without opening a picker.
- Bootstrap the file-tree lifecycle on its directory `BufEnter` entry point, then replay that event to the installed hijack handler.
- Register the JavaScript React and TypeScript React parser aliases synchronously because parser-backed contracts run before deferred Treesitter setup.

## Stuck

- `file-tree: Project tree shows files created outside Neovim` remains red at the observable `fee.go` `FileTreeGitUntracked` assertion.
- Probe: watcher reconciliation reached 256 handles with `sync_scheduled=false` and `event_confirmed=false`; after a pre-reconciliation sentinel and tree canary it reached `event_confirmed=true`, `settle_passes=0`, zero active debounce timers, and clean view/git state.
- Attempt 1 started the sentinel before reconciliation, waited for reconciliation, then confirmed the sentinel and tree canary; the case advanced past readiness but failed to colour `fee.go`.
- Attempt 2 additionally waited for every canary redraw, fallback scan, and git refresh to settle before creating `fee.go`; the same observable assertion failed.
- Saved attempt: `/Users/hlebbeladzed/.archon/workspaces/GlebBeloded/nvim.config/artifacts/runs/694c1dc1-5061-460f-bab9-c598588b8951/stuck-attempt-watch.diff`.
