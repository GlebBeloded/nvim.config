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

## Agent decisions

- The blocked-Differ regression uses a 250 ms helper deadline so it proves the diagnostic path well inside the specified 10 seconds without slowing the integration file.
