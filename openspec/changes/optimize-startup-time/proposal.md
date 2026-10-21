## Why

Kind: feature
Adopt: loop/optimize-startup-time-20261021-061156

Requested by the user (2026-10-20): "optimize startup time (should be snappy)".

## What Changes

- Neovim starts noticeably faster with the real config; the spec step measures the current startup and sets the
  target.
- The warmed real-config startup budget is tightened from 400 ms to 120 ms at idle-equivalent host load.
- Startup-only work stays synchronous; plugins and feature modules that are not needed for the initial screen load
  on their first real command, filetype, event, or action.
- Lua bytecode caching starts before the first custom module or plugin is loaded.

## Impact

- Baseline evidence: `make smoke-startup` measured 437.4 ms at a reported x3.5 host-load factor (about 125 ms
  idle-equivalent); a full-config probe reported 490.569 ms to `UIEnter` and 42 of 53 plugins loaded by `VeryLazy`.
- Architecture and load order: `init.lua`, `lua/gleb/options.lua`, `lua/gleb/plugins/init.lua`,
  `lua/gleb/plugins/plugins.lua`, and feature/action modules moved behind their existing runtime triggers.
- Verification: `tests/integration/plugins/test_startup.lua` and the base budget in `tests/smoke/run.lua`.
- No plugin dependency is added, removed, or upgraded; `lazy-lock.json` remains unchanged.
- Core keymaps do not change.
- `actions: Global bindings exist after VeryLazy` still holds because action registration and shortcut application remain synchronous through `VeryLazy`.
- `actions: Every configured mapping is action-owned` still holds because deferred implementations retain their synchronously registered action IDs and shortcut assignments.
- `actions: Unconfigured defaults are absent` still holds because startup optimization does not enable Neovim or plugin default mappings.
- `ai: Keymaps exist after VeryLazy` still holds because the AI actions and their configured mappings remain registered by `VeryLazy` even when implementation code loads on invocation.
- `ai: Entry mappings are silent` still holds because deferral does not change the registry-created mapping options.
- `ai: 99 entry mappings come from AI actions` still holds because the existing AI action IDs remain the owners of the configured entry mappings.
- `ai: Prompt submit comes from a filetype action` still holds because the submit action remains registered and its buffer-local mapping is still applied on filetype `99`.
- `autocommands: q closes special buffers through an action` still holds because the filetype-scoped close action remains registered before its special-buffer mapping is needed.
- `diff: Diff view mappings come from diff actions` still holds because diff-view mappings continue to be derived from registered diff actions when the view opens.
- `diff: Diff view reverting the last change keeps the view open` still holds because deferred initialization does not change empty-result view lifecycle.
- `file-tree: netrw is not loaded` still holds because deferred file-tree loading does not enable or source netrw.
- `file-tree: Requirement: Project tree open and close keys` still holds because tree action IDs remain synchronous and initialize the view on invocation.
- `file-tree: Requirement: Project tree keys` still holds because the deferred view continues to apply the registered filetype actions.
- `file-tree: Requirement: File tree nest actions` still holds because nesting behavior loads with the project-tree view on its first entry point.
- `find-action: Find Action is registered as an action` still holds because its action metadata remains synchronous while the picker implementation loads on invocation.
- `folding: Fold keys invoke registered actions` still holds because fold action IDs and mappings stay synchronous while fold implementation work may load on invocation.
- `git: Requirement: Changes panel window` still holds because changes actions load the panel implementation before opening its window.
- `git: Changes panel stages when cwd is outside the repository` still holds because the deferred action resolves repository-local state through the same implementation.
- `git: Changes panel unstages when cwd is outside the repository` still holds because the deferred action resolves repository-local state through the same implementation.
- `git: Changes panel mappings come from the shortcut file` still holds because the panel continues to derive its mappings from registered `changes.*` actions and `settings/keymap.json` when opened.
- `git: Diffview mappings come from git actions` still holds because Diffview continues to build its mappings from registered git actions when its view opens.
- `git: Diffview conflict choices come from git actions` still holds because the four conflict-choice action IDs and shortcut assignments remain registered before Diffview opens.
- `keymaps: Core mappings are noremap and silent` still holds because registry mapping options are unchanged by load deferral.
- `keymaps: Every core mapping has an area-action desc` still holds because action metadata remains synchronous and continues to supply each mapping description.
- `keymaps: Core mappings resolve through actions` still holds because core action IDs and shortcut application remain on the synchronous path while callbacks may load implementations on demand.
- `keymaps: Unadopted built-in mappings are removed` still holds because startup optimization does not change built-in mapping removal.
- `keymaps: Adopted built-in mappings are registry actions` still holds because adopted defaults retain their registered action ownership and configured assignments.
- `picker: Requirement: Picker input prompt` still holds because direct text-input actions initialize the shared picker frame before opening it.
- `pr: Requirement: Comments tab Enter` still holds because pull-request actions retain their synchronous IDs and load the implementation when invoked.
- `references: gr classifies Lua function calls and redefinitions` still holds because the references implementation and language facet load before the real `gr` request.
- `references: Lua usage types match the approved render` still holds because references initializes its shared frame palette before rendering.
- `select: Selection accepts omitted options` still holds because the synchronous wrapper forwards omitted options to the shared picker adapter.
- `select: Cancelling a code action completes selection` still holds because lazy initialization does not change the adapter callback contract.
- `select: Selection previews the current item` still holds because the shared select adapter loads before the first selection starts.
- `select: Omitted options open shared selection` still holds because the synchronous wrapper installs the adapter on first invocation.
- `shortcuts: Neovim mappings match the table` still holds because no physical key, received key, action assignment, or mapping is changed.
- `shortcuts: Shortcut meanings survive registry migration` still holds because deferred callbacks invoke the same action behavior through the real zellij stack.
 - Out of scope: visual changes, feature behavior changes, plugin upgrades, and cold starts that install dependencies.

## Rejected run
Run on `loop/optimize-startup-time-20261021-061156` was rejected by the judge:
- fix loop exhausted with gates still red: tests,stuck
- stuck: tasks.md `## Stuck` (earlier attempts, kept on the branch: not quoted here)
- last failures:
  make check is red:
  full log: /Users/hlebbeladzed/.archon/workspaces/GlebBeloded/nvim.config/artifacts/runs/694c1dc1-5061-460f-bab9-c598588b8951/check-3.log
  ok   lint             0.4 s
  ok   trace            0.6 s
  ok   types            2.0 s
  ok   specs            2.3 s
  FAIL test           650.1 s
  check: FAILED: test (650.3 s)
  ===== test (head) =====
  tests/integration/file-tree/test_performance.lua | file-tree: Project tree save leaves the main path promptly: x
  tests/integration/file-tree/test_performance.lua | file-tree: Project tree re-roots without waiting for repository discovery: x
  tests/integration/file-tree/test_performance.lua | file-tree: Project tree re-roots once with saved expansion: x
- note: loop: `FAIL in tests/integration/file-tree/test_performance.lua | file-tree: Project tree re-roots once with saved expansion: hung: no progress for 300 s (waiting for input or a never-met condition?)` and the file-tree watch cases fail on base `auto` too: the host's fseventsd is degraded (pegged CPU, multi-GB RSS), so every FSEvents stop blocks the main loop and events arrive late; restart fseventsd or reboot before the next gate. Orphaned test children from loop/pr-comments-view-20261020-141615 (ppid 1) are still running.
