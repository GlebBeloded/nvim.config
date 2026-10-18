## Why

Kind: feature
Depends: git-changes-tree

The queue builds an IntelliJ-style project tree (`file-tree-view` … `file-tree-ignored`), a commit tree (`git-changes-tree`) and an own diff view (`diff-engine-*`, `diff-view*`), all reachable only from Find Action so the old flows keep working meanwhile. The user decided to own the UI ("is diffbanding perfect? I want to own ui 100%") and to work as in IntelliJ ("I'm used to Idea", "I like IDEA IDE diff more"). This change makes the new UIs the default on the existing keys and removes the three plugins they replace. It is a breaking change: neo-tree, differ and codediff behaviour goes away.

## What Changes

- **Core keymaps** (user approval: the redesign, Decision below):
  - Alt+E (`<A-e>`) runs `file_tree.toggle` (was the neo-tree filesystem toggle `tree.toggle_filesystem`); opening reveals the current file.
  - Alt+Shift+G (`<A-G>`) runs `changes.toggle` (was the neo-tree git status toggle `tree.toggle_git_status`).
  - Cmd+G (`<A-g>`) runs `changes.review`, the changes panel with the diff of the current file (was `git.open_differ`). `diff.open_file` stays unbound, in Find Action.
- **Directory buffers** open the project tree as a sidebar; netrw is disabled (`netrwPlugin` in lazy.nvim's `disabled_plugins`).
- **Removed plugins:** neo-tree.nvim, differ.nvim and vscode-diff.nvim (codediff). Kept: diffview.nvim (merges with `diff3_mixed`, conflict choices), gitsigns, nui.nvim (the AI commit popup uses it), plenary, nvim-web-devicons.
- **Removed code:** the neo-tree setup and `diff_preview` module of `lua/gleb/file_tree/`, the neo-tree and tree-toggle actions, `lua/gleb/git/differ.lua` and `vscode_diff.lua` with their actions, the three plugin adapters, the codediff audit allowlist, the neo-tree highlight block of the colour scheme, the adapter-plugin names in Find Action's assignment.
- **`settings/keymap.json`:** 31 entries removed (`tree.*`, `neo_tree.*`, `differ.*`, `codediff.*`, `git.open_differ`); `file_tree.toggle`, `changes.toggle`, `changes.review` bound.
- **Bufferline** offsets the tabs over the changes panel too (`gleb-changes`), replacing the neo-tree entry.
- **Specs:** every neo-tree, differ and codediff requirement removed with its successor (design.md, Removed scenarios); the shortcut table and two `## Purpose` lines edited.

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `file-tree`: added "Project tree opens for a directory buffer" and "Project tree sidebar" (`file-tree-view`'s "Project tree window" without its pre-cutover scenario); modified "Filesystem tree toggle"; removed "Project tree window", "Tree sources and window", "Common tree open mappings", "Common tree edit mappings", "Filesystem source behaviour", "Git status navigation previews diffs", "Git status open, close and staging actions", "Git status staging matches exact paths", "Git status revert and key ownership", "Git status AI commit", "Git status push", "Diff preview state", "Diff preview opening", "Diff preview tree in diff tab", "Diff preview git errors", "Diff preview focus and closing", "Tree icons" and "Neo-tree mapping ownership".
- `git`: added "Changes review workflow" and "Diffview mapping ownership"; modified "Module loading"; removed "Differ viewer", "vscode-diff configuration", "Differ review workflow" and "Git plugin mapping ownership".
- `keymaps`: added "Changes review entry point", "Project tree and changes panel toggles" and "Pending panel work does not override a toggle"; modified "Normal-mode command maps bypass the command line" (no Ex command behind Cmd+G any more); removed "Differ entry point", "File tree and git panel toggles" and "Pending file tree work does not override a toggle".
- `bufferline`: modified "Tabline offset for the project tree" (also the changes panel); removed "Tabline offset for the file tree".
- `actions`: modified "Exclusive shortcut ownership" (no codediff allowlist; the new views instead of neo-tree, differ and codediff windows).
- Every removed scenario is listed with its successor in design.md, "Removed scenarios" (77 rows).

## Impact

- Code:
  - Removed: `lua/gleb/file_tree/neo_tree.lua`, `lua/gleb/file_tree/diff_preview.lua`, `lua/gleb/git/differ.lua`, `lua/gleb/git/vscode_diff.lua`, `lua/gleb/actions/adapters/neo_tree.lua`, `differ.lua`, `codediff.lua`.
  - Changed: `lua/gleb/file_tree/{init,actions}.lua` (hijack autocmd, old actions dropped), `lua/gleb/git/{init,actions}.lua`, `lua/gleb/plugins/plugins.lua`, the lazy.nvim setup (`disabled_plugins`), `lazy-lock.json`, `lua/gleb/bufferline.lua`, `lua/gleb/actions/{registry,audit}.lua`, `lua/gleb/find_action/assign.lua`, `lua/gleb/colors/gruvbox-material/git.lua`, `settings/keymap.json`.
  - Docs: docs/architecture.md, docs/testing.md; spec text: the shortcut table rows Cmd+E and Cmd+G, the `file-tree` and `git` Purpose lines.
  - Tests: cases of removed scenarios deleted with them; `tests/e2e/git/test_differ_review.lua` becomes `test_changes_review.lua`; render case `neo-tree` becomes `project-tree` plus a `changes` case; `tests/bootstrap.sh`/`tests/types.sh` drop vscode-diff.nvim; `tests/fixtures/build.sh` comment of `dirty`; the Find Action adapter fixture moves to a remaining adapter id.
- Plugins: removed nvim-neo-tree/neo-tree.nvim, undont/differ.nvim, esmuellert/vscode-diff.nvim. None added. nui.nvim stays: `lua/gleb/git/ai_commit.lua` is its remaining user.
- Core keymaps: yes, Alt+E, Alt+Shift+G and Cmd+G change meaning (user-approved redesign).
- Unchanged scenarios:
  - `shortcuts: Shortcut table names action ids` still holds: the task edits the Cmd+E and Cmd+G rows to the new action ids in the same commit as `settings/keymap.json`.
  - `shortcuts: Shortcut meanings survive registry migration` still holds: bytes, routing and received keys are unchanged; each row's action id is updated with the table.
  - `find-action: Adapter assignment reports deferred application` still holds: the test's adapter fixture moves to a remaining adapter id (`lazy.`), so the message is unchanged.
  - `find-action: Saved shortcut applies immediately` still holds: `file_tree.*` and `changes.*` are no adapter ids.
- Out of scope:
  - New tree, panel or diff behaviour (their own changes), diagnostics in the tree.
  - diffview and gitsigns configuration.
  - The loop prompts' wording "neo-tree renders are async" (`loop` capability).
  - Deleting installed plugin copies (`:Lazy clean`).

## Decision (user, 2026-10-17)

- Decision page: https://claude.ai/artifact/P7naTb7oU7Ke52P1QNkEdH
- Engine and UI: "port IDEA one, if it's not ported to lua yet"; "is diffbanding perfect? I want to own ui 100%".
- Panes: "Aligned, IntelliJ chrome"; "I like IDEA IDE diff more".
- File tree: sidebar 35 columns, IntelliJ rows; changes panel: IntelliJ commit tree.
- General: "I'm used to Idea".
- The redesign plan (scratch PLAN.md, "Actions and keys"), approved with these decisions: "Change K rebinds: `<A-e>` → `file_tree.toggle`, `<A-G>` → `changes.toggle`, `<A-g>` → `diff.open_file` (or the changes+diff view), and removes `tree.toggle_*`, `neo_tree.*`, `differ.*`, `codediff.*` entries; diffview stays (merges, `diffview.*`)."

## Decision (auditor, 2026-10-18, pre-implementation audit)

- Spec deltas: bufferline "Tabline offset for the project tree" is ADDED with all its scenarios (the main spec has no such requirement, so MODIFIED fails at archive). "Project tree sidebar" also keeps `Project tree toggle reveals the current file` and `Project tree opens from non-project buffers`. "Project tree editor-window hygiene" is MODIFIED to name the changes panel instead of neo-tree; "Project tree close-if-last isolation" is REMOVE+ADD (`Project and neo-tree close before the last editor` → `Project tree and changes panel close before the last editor`). Directory hijack: entering a directory buffer while a tree is open focuses that tree and never changes its root or cursor; the root is that directory only when no tree is open; `Project tree does not follow a directory buffer` gets a MODIFIED delta. Every removal is in the Removed table.
- Tasks also cover: the two `:Neotree` cases in `tests/integration/file-tree/test_project_tree.lua` and `file_tree/view.lua:72,86`; `tests/integration/find-action/test_run.lua` (catalog tables, the `neo_tree.open` fixture → `lazy.`); `tests/screen/find-action/test_palette.lua` with stand-in actions of the same titles so its 5 screenshots stay byte-identical; the `Core mappings resolve through actions` table; the NeoTree highlights in `colors/gruvbox-material/init.lua` and `colors/transparency.lua`. The `<A-e>` case of `test_tree.lua` is deleted in task 1, not task 5.
- Gates: Impact lists the `diff:` scenarios pinned through `diff.open_file`/`]f` as still holding, so `pinned.py` prints `none`. The 5.5 grep uses exact identifiers (`neo-tree|neo_tree|NeoTree|Neotree|differ\.|Differ|codediff|vscode.diff|diff_preview|open_differ`) and excludes `tests/unit/loop`. Existing bufferline screenshots pass unchanged; the changes-panel tabline case compares with a byte-identical `.ansi` copy under `tests/screen/bufferline/` plus real extmark groups; nothing is re-approved by the test run and nothing is read from `openspec/`. `Alt-g opens the changes review` uses the async wait budget, not 100 ms.
- Rollback: key rebinding (task 1) and plugin removal (task 5) land as separate commits; the sandbox keeps installed plugin copies. docs/architecture.md gets a "Moved keys" note (`H`→`I`, `?`→Find Action, `<`/`>`→Alt+E/Alt+Shift+G). `docs/testing.md:81` belongs to the loop-wording fix (applied by the auditor), so task 6.1 leaves it alone.
- Splits: 5.1 → 5a (git/actions tests updated) and 5b (file-tree test files and screenshots deleted after the successor check); 5.3 → 5c (file_tree, neo-tree, colours) and 5d (git differ/codediff, adapters, audit, assign, keymap.json); 5.4 → 5e (Find Action fixtures) and 5f (bootstrap, types, render cases, fixture comment); 3.1 (the e2e port) runs only after 5.3.

## Agent decisions

- **Cmd+G is the changes review,** not `diff.open_file` (design Decision 1): it keeps Cmd+G's current meaning (all changes, with a diff) and still lands on the current file when it changed.
- **Directory buffers open the sidebar,** not a tree in the current window as neo-tree's `open_current` did: there is one kind of tree window.
- **nui.nvim stays** for the commit popup; plenary and devicons stay for their other users.
- **Requirements that lose a scenario are replaced** (removed and added under a new name) because OpenSpec refuses a MODIFIED block that drops one; surviving scenario titles are kept so their tests keep their names.
