## Why

Kind: refactor

Depends: file-tree-performance, fix-file-tree-watch-limit

Repeated infrastructure across the tree, Changes panel and diff view (2026-10-19 inventory):

- Hand-written debounce timers 6 times: `file_tree/watch.lua:40`, `file_tree/git.lua:188`, `file_tree/expanded.lua:81`,
  `file_tree/view.lua:820`, `git/changes/view.lua:517-518`, `diff/view/init.lua:296` (inconsistent `schedule_wrap`).
- `git/changes` reaches into project-tree internals: `fs`, `model`, `nesting`, `settings`, `watch`, `view` are required
  from `git/changes/{git,model,view,init}.lua:5-11`; the porcelain-v2 parsing lives in `file_tree/model.lua:147,189`.
- `git/changes/git.lua` (358 lines) repeats `vim.system` + `vim.schedule` + callback 13 times.

## What Changes

- `gleb.util.debounce` (one timer helper, scheduled callbacks) used by all six sites.
- A neutral module (e.g. `gleb.workspace` / `gleb.git.status`) for the shared fs scan, porcelain-v2 parsing and nesting,
  required by both `file_tree` and `git/changes`; neither requires the other's internals afterwards.
- One `run_git(args, cwd, cb)` in `git/changes/git.lua` for the 13 call sites.
- Behaviour unchanged: every scenario keeps its test and bounds; follow docs/architecture.md module conventions.

## Impact

- `lua/gleb/file_tree/*`, `lua/gleb/git/changes/*`, `lua/gleb/diff/view/init.lua`, a new `lua/gleb/util/` helper and the
  neutral module.
