## 1. Bound plugin-surface opens
Scenarios: `actions: Plugin-window mappings are action-owned`
- [x] 1.1 Use `FAIL in tests/integration/actions/test_plugin_ownership.lua | actions: Plugin-window mappings are action-owned: hung: no progress for 300 s (waiting for input or a never-met condition?)` as the failing evidence, then tighten `tests/integration/actions/test_plugin_ownership.lua` to require a named diagnostic within 10 seconds when the real populated `:Differ` surface blocks
- [x] 1.2 Add a process-level surface-open deadline in `tests/helpers.lua` that records the surface, phase, elapsed time, child mode, `vim.fn.getchar(1)` state, and messages before stopping an unresponsive child; drive every existing `open_surface` call through it without skipping a surface or changing mapping assertions
- [x] 1.3 Run `make test FILE=tests/integration/actions/test_plugin_ownership.lua CASE="Plugin-window mappings are action-owned"` and see it pass

## 2. Bound the Differ viewer scenario
Scenarios: `git: Differ opens panel on the left`
- [x] 2.1 Use `FAIL in tests/integration/git/test_git.lua | git: Differ opens panel on the left: hung: no progress for 300 s (waiting for input or a never-met condition?)` as the failing evidence, then update `tests/integration/git/test_git.lua` to drive the real `:Differ` command with populated working-tree changes through the bounded helper and require its named diagnostic within 10 seconds when blocked
- [x] 2.2 Keep the panel position, width, and tree-content assertions unchanged
- [x] 2.3 Run `make test FILE=tests/integration/git/test_git.lua CASE="Differ opens panel on the left"` and see it pass

## 3. Tighten blocked-Differ diagnostics
Scenarios: `actions: Plugin-window mappings are action-owned`, `git: Differ opens panel on the left`
- [x] 3.1 Require the blocked-Differ diagnostic phase to be `opening`, proving the stubbed git call was reached
- [x] 3.2 Always stop each blocked-Differ child after the bounded open attempt
- [x] 3.3 Record live child subprocess commands in surface state and failure diagnostics, and require the regression diagnostic to name `sleep`

## Agent decisions

- The blocked-Differ regressions use helper deadlines of at most one second so they reach the stubbed git call and prove the diagnostic path well inside the specified 10 seconds.
- The ownership audit disables Mason's optional outdated-package refresh because it audits local mappings, not remote package metadata.
