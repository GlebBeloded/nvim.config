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
- `bufferline: tabs start after the open project tree` still holds because the refactor preserves tree width and tabline offsets.
- `bufferline: tabline with tree open matches reference screenshot` still holds because no rendered layout changes.
- `bufferline: tabline without tree matches reference screenshot` still holds because no rendered layout changes.
- `file-tree: Requirement: Project tree open and close keys` still holds because tree actions and mappings are unchanged.
- `file-tree: Requirement: Project tree folds` still holds because fold actions and state are unchanged.
- `file-tree: Project tree reads git status without optional locks` still holds because the shared runner preserves git arguments.
- `file-tree: Project tree runs git status once per burst` still holds because debounce timing and coalescing are preserved.
- `file-tree: Project tree reveal focuses the current file` still holds because reveal behavior is unchanged.
- `file-tree: Project tree reveal tolerates a deleted file` still holds because reveal error handling is unchanged.
- `file-tree: Project tree toggle tolerates a deleted file` still holds because toggle error handling is unchanged.
- `file-tree: Project tree watchers stop when the tree closes` still holds because timer and watcher cleanup are preserved.
- `file-tree: Project tree expanded folders persist per root` still holds because expansion persistence and debounce timing are preserved.
- `file-tree: Project tree keys come from the keymap file` still holds because mappings are unchanged.
- `file-tree: Project tree matches the approved render` still holds because rendering is unchanged.
- `file-tree: Requirement: Project tree create` still holds because create operations are unchanged.
- `file-tree: Requirement: Project tree rename` still holds because rename operations are unchanged.
- `file-tree: Requirement: Project tree delete` still holds because delete operations are unchanged.
- `file-tree: Project tree x and p move a file like a rename` still holds because move operations are unchanged.
- `file-tree: Project tree R picks up changes at once` still holds because refresh behavior is unchanged.
- `file-tree: Requirement: Project tree refresh isolation` still holds because refresh state remains isolated per tree.
- `file-tree: Nesting rule nests by capture` still holds because the same nesting implementation moves behind a neutral module.
- `file-tree: Requirement: File tree default nesting rules` still holds because default rules are unchanged.
- `file-tree: Nests start collapsed under a chevron` still holds because nest state and rendering are unchanged.
- `file-tree: Added nested file is revealed in its nest` still holds because nested reveal behavior is unchanged.
- `file-tree: Deleting a nest parent keeps its children` still holds because nested delete behavior is unchanged.
- `file-tree: File tree nests match the approved render` still holds because nest rendering is unchanged.
- `file-tree: Ignored entries are hidden by default` still holds because scan filtering is preserved.
- `file-tree: Show Ignored persists` still holds because settings persistence is unchanged.
- `file-tree: Saved Show Ignored state is restored` still holds because settings loading is unchanged.
- `file-tree: Ignored folders do not compact or consume unfold budget` still holds because filtering precedes compaction as before.
- `file-tree: Requirement: Shared porcelain status records` is updated to name the neutral `gleb.git.status` API.
- `file-tree: Project tree opens on the left at width 35` still holds because window placement is unchanged.
- `file-tree: Project tree toggle closes a focused tree` still holds because toggle behavior is unchanged.
- `file-tree: Project tree toggle focuses an open tree` still holds because toggle behavior is unchanged.
- `file-tree: Project tree toggle reveals the current file` still holds because toggle behavior is unchanged.
- `file-tree: Project tree opens from non-project buffers` still holds because root discovery is unchanged.
- `file-tree: Project tree redraw meets the large-tree bound` still holds because the refactor preserves the bound.
- `file-tree: Requirement: Project tree unfolds in linear time` still holds because traversal behavior is unchanged.
- `git: Requirement: Changes panel nesting` still holds because the same nesting implementation moves behind a neutral module.
- `git: Changes panel replaces the project tree` still holds because panel replacement behavior is unchanged.
- `git: Project tree replaces the changes panel` still holds because panel replacement behavior is unchanged.
- `git: Project tree replaces a last-window changes panel` still holds because last-window replacement behavior is unchanged.
- `keymaps: Requirement: Project tree and changes panel toggles` still holds because action mappings and toggle effects are unchanged.
