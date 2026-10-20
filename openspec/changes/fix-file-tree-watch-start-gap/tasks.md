## 1. Keep fallback coverage through watch startup
Scenarios: `file-tree: Project tree shows files created outside Neovim`
- [x] 1.1 Extend `tests/integration/file-tree/test_project_live.lua` through the real `file_tree.toggle` action and populated `treeproj` data so two fallback scans can complete before a canary event and an external `touch`; run `make test FILE=tests/integration/file-tree/test_project_live.lua CASE="Project tree shows files created outside Neovim"` against the elapsed-pass logic and see it fail
- [x] 1.2 Change `lua/gleb/tree/watch.lua` so watch starts and restarts keep fallback scans armed until the first confirmed event, then count the bounded settle passes without weakening unwatched-folder coverage
- [x] 1.3 Run `make test FILE=tests/integration/file-tree/test_project_live.lua CASE="Project tree shows files created outside Neovim"` and see it pass

## 2. Prove the live stream before project-tree mutations
Scenarios: `file-tree: A compact chain splits when a folder gains an entry`, `file-tree: Every compact chain member is watched`, `file-tree: Project tree isolates tabpage state`
- [ ] 2.1 Add a canary-event wait to `tests/integration/file-tree/test_project_live.lua` before each scenario's external filesystem mutation; with a temporary fault that suppresses the canary write, run each scenario with `make test FILE=tests/integration/file-tree/test_project_live.lua CASE="<scenario title>"`, see and record the failed canary wait, then remove the fault
- [ ] 2.2 Run each scenario with `make test FILE=tests/integration/file-tree/test_project_live.lua CASE="<scenario title>"` and see it pass

## 3. Observe copied nest rows before renaming
Scenarios: `file-tree: Renaming a nest parent migrates its state`, `file-tree: Renaming a folder migrates nest state in every view`
- [ ] 3.1 Make `tests/integration/file-tree/test_nesting.lua` wait through the real tree view for each copied child's row before invoking the real `r` mapping; with a temporary fault that omits the copy, run each scenario with `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="<scenario title>"`, see and record the failed row wait, then remove the fault
- [ ] 3.2 Run each scenario with `make test FILE=tests/integration/file-tree/test_nesting.lua CASE="<scenario title>"` and see it pass

## 4. Confirm the restarted watcher after refresh
Scenarios: `file-tree: Project tree R picks up changes at once`
- [ ] 4.1 Extend `tests/integration/file-tree/test_project_ops.lua` to wait for a canary event through the restarted watcher after the real `R` mapping; with a temporary fault that suppresses the canary write, run `make test FILE=tests/integration/file-tree/test_project_ops.lua CASE="Project tree R picks up changes at once"`, see and record the failed canary wait, then remove the fault
- [ ] 4.2 Run `make test FILE=tests/integration/file-tree/test_project_ops.lua CASE="Project tree R picks up changes at once"` and see it pass

## Agent decisions

- Track event confirmation per root because libuv rebuilds one shared stream for that root's folder, git, and recursive handles.
