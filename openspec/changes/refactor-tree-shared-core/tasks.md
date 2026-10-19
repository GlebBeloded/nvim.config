## 1. Centralize project-tree watcher debounce
Scenarios: `file-tree: Project tree watchers stop when the tree closes`
- [x] 1.1 Run `make test FILE=tests/integration/file-tree/test_project_live.lua CASE="Project tree watchers stop when the tree closes"` and see it pass, add the scheduled `gleb.util.debounce` helper and migrate `file_tree/watch.lua`, then run it again and see it pass

## Agent decisions

- `gleb.util.debounce.schedule` accepts and returns a reusable timer so each consumer retains ownership of lifecycle cleanup.
- Project-tree redraw replaces its timer before scheduling so a queued stale callback remains distinguishable from the current debounce.
- Shared scanning lives at `gleb.workspace` and porcelain parsing at `gleb.git.status`, matching their workspace and Git ownership while retaining the old filesystem import as a compatibility alias.
- Shared tree infrastructure lives under `gleb.tree`, with compatibility aliases for existing file-tree callers so the Changes panel has no project-tree dependency.

## 2. Migrate project-tree git and expansion debounce
Scenarios: `file-tree: Project tree runs git status once per burst`, `file-tree: Project tree expanded folders persist per root`
- [x] 2.1 Run `make test FILE=tests/integration/file-tree/test_project_git.lua CASE="Project tree runs git status once per burst"` and `make test FILE=tests/integration/file-tree/test_project_live.lua CASE="Project tree expanded folders persist per root"` and see them pass, migrate `file_tree/git.lua` and `file_tree/expanded.lua` to `gleb.util.debounce`, then run them again and see them pass

## 3. Migrate project-tree redraw debounce
Scenarios: `file-tree: Project tree redraw meets the large-tree bound`
- [x] 3.1 Run `make test FILE=tests/integration/file-tree/test_performance.lua CASE="Project tree redraw meets the large-tree bound"` and see it pass, migrate the listed `file_tree/view.lua` debounce site to `gleb.util.debounce`, then run it again and see it pass

## 4. Migrate Changes-panel and diff-view debounce
Scenarios: `git: Changes panel debounces rapid moves`, `git: Changes panel drops a stale diff result`
- [x] 4.1 Run `make test FILE=tests/integration/git/test_changes_diff.lua CASE="Changes panel debounces rapid moves"` and `make test FILE=tests/integration/git/test_changes_diff.lua CASE="Changes panel drops a stale diff result"` and see them pass, migrate the listed `git/changes/view.lua` and `diff/view/init.lua` debounce sites to `gleb.util.debounce`, then run them again and see them pass

## 5. Extract shared filesystem scan and porcelain parser
Scenarios: `file-tree: Shared parser preserves rename and copy origins`, `file-tree: Shared parser classifies added and unmerged records`, `file-tree: Shared parser keeps ignored records separate`, `git: Changes panel status avoids optional locks`
- [x] 5.1 Run `make test FILE=tests/unit/file-tree/test_model.lua CASE="Shared parser preserves rename and copy origins"`, `make test FILE=tests/unit/file-tree/test_model.lua CASE="Shared parser classifies added and unmerged records"`, `make test FILE=tests/unit/file-tree/test_model.lua CASE="Shared parser keeps ignored records separate"`, and `make test FILE=tests/integration/git/test_changes.lua CASE="Changes panel status avoids optional locks"` and see them pass, move the shared filesystem scan and porcelain-v2 parsing into neutral modules and update both consumers, then run them again and see them pass

## 6. Extract shared nesting from project-tree internals
Scenarios: `file-tree: Nesting rule nests by capture`, `git: Changes panel nests tests under their file`
- [x] 6.1 Run `make test FILE=tests/unit/file-tree/test_nesting.lua CASE="Nesting rule nests by capture"` and `make test FILE=tests/unit/git/test_changes_model.lua CASE="Changes panel nests tests under their file"` and see them pass, move shared nesting into the neutral module and remove `git/changes` imports of project-tree `fs`, `model`, `nesting`, `settings`, `watch`, and `view` internals, then run them again and see them pass

## 7. Consolidate Changes-panel git process execution
Scenarios: `git: Changes panel status avoids optional locks`, `git: Changes panel Space stages an unstaged file`, `git: Changes panel X reverts a file after confirmation`, `git: Changes panel review shows the current file's diff`
- [ ] 7.1 Run `make test FILE=tests/integration/git/test_changes.lua CASE="Changes panel status avoids optional locks"`, `make test FILE=tests/integration/git/test_changes_stage.lua CASE="Changes panel Space stages an unstaged file"`, `make test FILE=tests/integration/git/test_changes_actions.lua CASE="Changes panel X reverts a file after confirmation"`, and `make test FILE=tests/integration/git/test_changes_diff.lua CASE="Changes panel review shows the current file's diff"` and see them pass, add one scheduled-callback `run_git(args, cwd, cb)` in `git/changes/git.lua` and migrate all 13 call sites, then run them again and see them pass
