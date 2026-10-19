## 1. Reap a blocked surface's process tree
Scenarios: `actions: Plugin-window mappings are action-owned`
- [x] 1.1 Extend `tests/integration/actions/test_plugin_ownership.lua` through the real `H.open_surface` entry point with a blocked child that starts a shell-owned `sleep`; run `make test FILE=tests/integration/actions/test_plugin_ownership.lua CASE="Plugin-window mappings are action-owned"` and see it fail because the descendant remains alive
- [x] 1.2 Make `stop_blocked_child` in `tests/helpers.lua` collect the blocked Neovim child's complete process tree and kill descendants leaf-first before killing Neovim, while preserving every active surface assertion and skipping none
- [x] 1.3 Run `make test FILE=tests/integration/actions/test_plugin_ownership.lua CASE="Plugin-window mappings are action-owned"` and see it pass

## Agent decisions

- `tree-diff-cutover` has retired `Differ` and `differ.nvim`, as guarded by `git: Removed diff plugins are not registered`; under the proposal's explicit condition, the Differ cwd/timing probes and fixture changes no longer apply, so this plan keeps only the general blocked-surface process-tree fix.
- Cleanup takes a fresh recursive process snapshot immediately before signaling, so descendants spawned after diagnostic capture are still reaped leaf-first.
