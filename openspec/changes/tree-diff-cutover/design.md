## Context

After `file-tree-view` … `git-changes-tree` the new project tree, the changes panel and the IntelliJ-style diff view exist next to the old flows, reachable only from Find Action. Today's keys still open neo-tree (`<A-e>` filesystem, `<A-G>` git status with the codediff preview tab) and differ (`<A-g>`), and three diff tools are installed side by side "to compare both flows" (docs/architecture.md, Key decisions). The user decided to own the UI ("I want to own ui 100%"), so this change makes the new UIs the default and removes what they replace. It is the only change of the queue that modifies or removes existing requirements.

What stays: diffview.nvim for merges (`diff3_mixed`, the conflict choices `<leader>co`/`ct`/`cb`/`ca`, `dx`) and its file panel; gitsigns for gutter signs; nui.nvim, used by the AI commit popup (`lua/gleb/git/ai_commit.lua` requires `nui.popup` and `nui.utils.autocmd`); plenary (diffview, gitlinker, telescope, neotest); nvim-web-devicons (project tree, changes panel, bufferline).

## Goals / Non-Goals

**Goals:**
- `<A-e>` → project tree, `<A-G>` → changes panel, `<A-g>` (Cmd+G) → changes review; directory buffers open the project tree.
- neo-tree, differ.nvim and vscode-diff.nvim (codediff) uninstalled, with every module, adapter, action, key entry, test and doc line that only served them.
- Every removed requirement and scenario named with its reason and its successor.

**Non-Goals:**
- New behaviour in the tree, the panel or the diff view (their own changes).
- Replacing diffview for merges, or gitsigns.
- The loop's prompt wording "LSP restart and neo-tree renders are async" (`loop` capability, `.archon/commands/*.md`, `tests/unit/loop/test_probe.lua`): still true advice for any async tree render; a follow-up fix can reword it.

## Decisions

1. **Cmd+G is the changes review** (`changes.review`), not `diff.open_file`. Today Cmd+G opens differ: a panel of every changed file with the diff of the selected one. `changes.review` keeps that meaning in the IntelliJ form the user picked (commit tree + diff in the editor area) and starts on the current file when it changed, so "diff of this file" is still one key away. `diff.open_file` stays in Find Action; in-buffer hunks stay on gitsigns. `<A-G>` (`changes.toggle`) only toggles the panel, like neo-tree's git status today.
2. **`<A-e>` reveals the current file.** `file_tree.toggle` opens the tree with its cursor on the current buffer's file when it exists under the root (the follow rule of `file-tree-view` applied at open), else on the root row, as neo-tree's smart toggle did. URI buffers (`diffview://…`) and deleted files fall back to the root row without an error.
3. **One left tool window.** `<A-G>` from the project tree closes it and opens the changes panel, and `<A-e>` the reverse (`git: Changes panel shares the left side`), replacing neo-tree's source switch in one window.
4. **Directory buffers.** netrw is disabled with lazy.nvim's `performance.rtp.disabled_plugins = { "netrwPlugin" }` (lazy sources runtime plugins itself, so a `g:loaded_*` set later in `init.lua` would come too late). A `BufEnter` autocmd (`gleb_file_tree_hijack`) on a directory buffer swaps the window to an empty buffer, wipes the directory buffer and opens the project tree rooted at that directory (`file-tree-view`'s open with an explicit root; this change adds the `root` option if that change has none). Unlike neo-tree's `open_current`, the tree stays a sidebar: there is one kind of tree window.
5. **Removed plugins** (`lua/gleb/plugins/plugins.lua`, `lazy-lock.json`): `nvim-neo-tree/neo-tree.nvim` (v3.x), `undont/differ.nvim` (with its Go sidecar build), `esmuellert/vscode-diff.nvim`. nui.nvim keeps its own top-level entry. diffview's comment changes from "kept installed so the old flow stays comparable" to merges and history. Installed copies are left for `:Lazy clean`.
6. **Removed code:**
   - `lua/gleb/file_tree/neo_tree.lua` (the neo-tree setup `file-tree-view` moved there), `lua/gleb/file_tree/diff_preview.lua`, and in `lua/gleb/file_tree/actions.lua` the smart toggle, the `git_*` helpers and every `neo_tree.*`/`tree.*` action.
   - `lua/gleb/git/differ.lua`, `lua/gleb/git/vscode_diff.lua`; in `lua/gleb/git/actions.lua` `git.open_differ` and the `differ`/`codediff` viewer actions (`replay_shortcut` goes when unused).
   - `lua/gleb/actions/adapters/{neo_tree,differ,codediff}.lua`; the `neo_tree_scope` field of `gleb.Action` in `registry.lua`; the codediff entries of `NATIVE` in `audit.lua`; the `codediff`, `differ`, `file_tree` and `neo_tree` entries of `ADAPTER_PLUGINS` in `find_action/assign.lua`.
   - `lua/gleb/colors/gruvbox-material/git.lua` drops the `neo-tree.ui.highlights` block and keeps the `Diff*` colours.
7. **`settings/keymap.json`.** Removed: `tree.toggle_filesystem`, `tree.toggle_git_status`, `git.open_differ`, `differ.next_file`, `differ.next_hunk`, `codediff.next_hunk` and all 25 `neo_tree.*` entries. Added: `file_tree.toggle` `<A-e>`, `changes.toggle` `<A-G>`, `changes.review` `<A-g>`. No other lhs changes; the scoped keys of the new views come from their own changes.
8. **Bufferline offsets** (`lua/gleb/bufferline.lua`): the `neo-tree` entry is replaced by `gleb-changes` next to `gleb-file-tree` (added by `file-tree-view`), both with no text, padding 1 and the panel's highlight.
9. **Spec text outside requirements** is edited by the tasks, as `fix-cmd-shift-minus-equal` did for the shortcut table: the `## Shortcut table` rows Cmd+E (`file_tree.toggle`) and Cmd+G (`changes.review`) of `openspec/specs/shortcuts/spec.md`, and the `## Purpose` lines of `file-tree` ("The project tree sidebar …") and `git` (no differ/vscode-diff; changes panel and diffview for merges).
10. **Requirement replacement.** OpenSpec refuses a MODIFIED block that drops a scenario, so a requirement that loses one is REMOVED and re-ADDED under a new name, keeping the surviving scenario titles (and their tests): "File tree and git panel toggles" → "Project tree and changes panel toggles", "Pending file tree work does not override a toggle" → "Pending panel work does not override a toggle", "Git plugin mapping ownership" → "Diffview mapping ownership", and `file-tree-view`'s "Project tree window" → "Project tree sidebar".
11. **Tests follow their scenarios.** Cases of removed scenarios are deleted with them; each has its successor listed in the delta. The differ e2e workflow becomes the changes review workflow (`tests/e2e/git/test_changes_review.lua`, same `dirty` fixture and manifest). The `neo-tree` render case becomes `project-tree`, and a `changes` case (the `billing` fixture) is added. `make deps`/`make types` stop fetching vscode-diff.nvim as a type library.
12. **Docs** (rule 10): docs/architecture.md (module map rows of `git/` and `file_tree/`, the startup flowchart label, the plugin-config list, the keymaps, file-tree and git key decisions) and docs/testing.md (`make deps` libraries, the codediff example under "How bugs become tests", the probing note) stop naming the removed plugins.

## Removed scenarios

Every scenario this change removes, with its successor (the deltas carry the reasons):

| Capability: removed scenario | Successor |
|---|---|
| file-tree: Filesystem tree opens on the left at width 35 | file-tree: Project tree opens on the left at width 35 |
| file-tree: Git status tree opens on the left at width 35 | git: Changes panel opens on the left at width 35 |
| file-tree: Tree closes with last window | file-tree: Project tree closes with the last window |
| file-tree: Missing neo-tree is tolerated | none: own code, no plugin to miss |
| file-tree: v opens file in vertical split | file-tree: Project tree v opens a vertical split |
| file-tree: t opens file in new tab | file-tree: Project tree t opens a new tab |
| file-tree: Next source switches tree source | keymaps: Alt-G replaces the project tree with the changes panel |
| file-tree: o and l keep native open in git status tree | git: Changes panel Enter opens the file |
| file-tree: a creates a file | file-tree: Project tree a creates a file in the folder under the cursor |
| file-tree: r renames a file | file-tree: Project tree r renames a file and its buffer |
| file-tree: Dotfiles and gitignored files are listed | file-tree: Project tree lists folders first in case-insensitive order; file-tree: I toggles ignored entries |
| file-tree: Directory argument opens tree in current window | file-tree: Directory argument opens the project tree |
| file-tree: Current file is followed | file-tree: Project tree follows the current file |
| file-tree: j skips directories and previews next file | git: Changes panel j shows the next file in the diff view |
| file-tree: k skips directories and previews previous file | git: Changes panel keeps the diff on a directory row |
| file-tree: Deleted file is not previewed | git: Changes panel shows a deleted file |
| file-tree: Enter opens file and switches to filesystem tree | git: Changes panel Enter opens the file |
| file-tree: q closes preview and tree | git: Changes panel q closes the panel and the diff view |
| file-tree: Space stages an unstaged file | git: Changes panel Space stages an unstaged file |
| file-tree: Space unstages a staged file | git: Changes panel Space unstages a staged file |
| file-tree: Space stages a file whose name is a suffix of a staged file | git: Changes panel Space stages a file whose name is a suffix of a staged file |
| file-tree: Space stages when cwd is outside the repository | git: Changes panel stages when cwd is outside the repository |
| file-tree: Space unstages when cwd is outside the repository | git: Changes panel unstages when cwd is outside the repository |
| file-tree: Space stages from a subdirectory cwd | git: Changes panel stages from a subdirectory cwd |
| file-tree: Space unstages from a subdirectory cwd | git: Changes panel unstages from a subdirectory cwd |
| file-tree: Space reports a staging failure | git: Changes panel reports a staging failure |
| file-tree: X reverts a file after confirmation | git: Changes panel X reverts a file after confirmation |
| file-tree: X keeps a file when revert is declined | git: Changes panel X keeps a file when revert is declined |
| file-tree: gr keeps its global meaning in git status tree | git: Changes panel leaves gr global |
| file-tree: c is copy in git status tree | file-tree: Project tree c and p copy a file into another folder |
| file-tree: gc commits confirmed message | git: Changes panel gc commits confirmed message |
| file-tree: gc reports commit failure | git: Changes panel gc reports commit failure |
| file-tree: Help lists the moved git status keys | none: no neo-tree help popup; Find Action lists the keys |
| file-tree: P pushes successfully | git: Changes panel P pushes successfully |
| file-tree: P reports push failure | git: Changes panel P reports push failure |
| file-tree: State starts empty | none: the preview module is removed |
| file-tree: Reset clears populated state | none: the preview module is removed |
| file-tree: Nil path is ignored | none |
| file-tree: Same file is ignored | git: Changes panel j shows the next file in the diff view |
| file-tree: Current file is tracked immediately | none: no tab |
| file-tree: Original tab is saved | none: no tab |
| file-tree: Diff tab is created | none: no tab |
| file-tree: Diff tab is reused across files | git: Changes panel j shows the next file in the diff view |
| file-tree: Rapid calls are debounced | git: Changes panel debounces rapid moves |
| file-tree: Neo-tree is opened and focused in diff tab | git: Changes panel j shows the next file in the diff view |
| file-tree: File outside a repository | git: Changes panel outside a repository |
| file-tree: Focus returns false without neo-tree | git: Changes panel j shows the next file in the diff view |
| file-tree: Focus moves to neo-tree | git: Changes panel j shows the next file in the diff view |
| file-tree: Focus guard pulls focus back during navigation | git: Changes panel j shows the next file in the diff view |
| file-tree: Return to original tab | git: Changes panel q closes the panel and the diff view |
| file-tree: Return clears current file | git: Changes panel q closes the panel and the diff view |
| file-tree: Return clears tab state and focus guard | git: Changes panel q closes the panel and the diff view |
| file-tree: Next preview records the new original tab | none: no tab |
| file-tree: Return cancels a pending preview | git: Changes panel debounces rapid moves |
| file-tree: Collapsed directory shows expander and folder icon | file-tree: Project tree rows have icons and no guides |
| file-tree: Expanded directory shows open expander and folder icon | file-tree: Project tree rows have icons and no guides |
| file-tree: Empty directory shows empty folder icon | file-tree: Project tree rows have icons and no guides |
| file-tree: Tree shows diagnostic glyph of a file | none: diagnostics in the tree are out of scope (`file-tree-view`) |
| file-tree: Conflicted file shows conflict symbol | file-tree: Project tree colours renamed and conflicted files |
| file-tree: filesystem tree matches reference screenshot | file-tree: Project tree matches the approved render |
| file-tree: Tree mappings come from the shortcut file | file-tree: Project tree keys come from the keymap file; git: Changes panel mappings come from the shortcut file |
| file-tree: Neo-tree defaults stay disabled | none: no plugin defaults |
| file-tree: Project tree actions start unbound (`file-tree-view`) | keymaps: Alt-e reveals current file |
| git: Differ opens panel on the left | git: Changes panel opens on the left at width 35 |
| git: vscode-diff setup runs on plugin load | none: no plugin |
| git: Cmd+G opens differ listing every change of a dirty repo | git: Cmd+G opens the changes review of a dirty repo |
| git: ]f steps to the next changed file in differ | git: ]f steps to the next changed file in the changes review |
| git: ]c steps to the next hunk in differ | git: ]c steps to the next change in the changes review |
| git: Differ mappings come from git actions | none: no differ |
| git: Codediff mappings come from git actions | none: no codediff |
| keymaps: Alt-e on URI buffer focuses filesystem | keymaps: Alt-e on URI buffer focuses the project tree |
| keymaps: Alt-e closes focused filesystem tree | keymaps: Alt-e closes the focused project tree |
| keymaps: Alt-G switches tree to git status | keymaps: Alt-G replaces the project tree with the changes panel |
| keymaps: Alt-G closes focused git status tree | keymaps: Alt-G closes the focused changes panel |
| keymaps: Alt-g opens Differ | keymaps: Alt-g opens the changes review |
| keymaps: Toggle wins over pending filesystem render | keymaps: Toggle wins over a pending tree refresh; keymaps: Toggle wins over a pending changes refresh |
| bufferline: tabs start after the open tree | bufferline: tabs start after the open project tree |

Kept titles under a renamed requirement: `keymaps: Alt-e reveals current file`, `keymaps: Alt-e tolerates a deleted current file`, `git: Diffview mappings come from git actions`, `git: Diffview conflict choices come from git actions`, `bufferline: tabline with tree open matches reference screenshot`, `bufferline: tabline without tree matches reference screenshot`, and `file-tree-view`'s four "Project tree …" window scenarios.

## Renders

The only new visible behaviour is the tabline offset over the changes panel; the tree, the panel and the diff view keep the renders of their own changes. Stand-ins as in `git-changes-tree`. Real-glyph, real-colour copies: `renders/*.ansi`. `make colorize FILE=openspec/changes/tree-diff-cutover/design.md` reports the `Changes*`/`FileTree*` groups as unknown until those changes land.

**Current — tabline over the changes panel**: `100x4`, excerpt: tabline and the first panel rows, Normal, `billing` fixture, `internal/billing/invoice.go` edited, `changes.toggle` (after `git-changes-tree`): bufferline offsets only `neo-tree` and `gleb-file-tree`, so the tab starts at column 1 over the panel.

```text
 ◆ invoice.go                                                                                       
 ▾ ◪ Changes 5 files               ┃   1 package billing                                            
   ▾ □ internal/billing 4          ┃   2                                                            
     ▾ ☐ ◆ invoice.go       +12 -3 ┃   3 import (                                                   
```

```text
abaaaaaaaaaaaaaccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
dedfdgggggggdhhhhhhhdddddddddddddddijjjjjkkkkkkk....................................................
dddedldmmmmmmmmmmmmmmmmdhddddddddddinnnnn...........................................................
oooooeofoboppppppppppoooooooqqqorroinnnnnkkkkkk.....................................................
```

Legend: `a` [BufferLineBufferSelected] · `b` [DevIconGo] · `c` [BufferLineFill] · `d` [FileTreeNormal] · `e` [FileTreeExpander] · `f` [ChangesCheckbox] · `g` [ChangesRoot] · `h` [ChangesCount] · `i` [WinSeparator] · `j` [CursorLineNr] · `k` [@keyword] · `l` [FileTreeFolderIcon] · `m` [FileTreeFolderName] · `n` [LineNr] · `o` [FileTreeCursorLine] · `p` [FileTreeGitModified] · `q` [ChangesStatAdded] · `r` [ChangesStatRemoved] · `.` [Normal]

**Proposed — tabline over the changes panel**: `100x4`, same state: the tab starts at column 37, the offset area in the panel's highlight.

```text
                                     ◆ invoice.go                                                   
 ▾ ◪ Changes 5 files               ┃   1 package billing                                            
   ▾ □ internal/billing 4          ┃   2                                                            
     ▾ ☐ ◆ invoice.go       +12 -3 ┃   3 import (                                                   
```

```text
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabcbbbbbbbbbbbbbddddddddddddddddddddddddddddddddddddddddddddddddd
aeafagggggggahhhhhhhaaaaaaaaaaaaaaaijjjjjkkkkkkk....................................................
aaaealammmmmmmmmmmmmmmmahaaaaaaaaaainnnnn...........................................................
oooooeofocoppppppppppoooooooqqqorroinnnnnkkkkkk.....................................................
```

Legend: `a` [FileTreeNormal] · `b` [BufferLineBufferSelected] · `c` [DevIconGo] · `d` [BufferLineFill] · `e` [FileTreeExpander] · `f` [ChangesCheckbox] · `g` [ChangesRoot] · `h` [ChangesCount] · `i` [WinSeparator] · `j` [CursorLineNr] · `k` [@keyword] · `l` [FileTreeFolderIcon] · `m` [FileTreeFolderName] · `n` [LineNr] · `o` [FileTreeCursorLine] · `p` [FileTreeGitModified] · `q` [ChangesStatAdded] · `r` [ChangesStatRemoved] · `.` [Normal]

## Risks / Trade-offs

- **Breaking change.** Muscle memory for neo-tree keys (`H`, `<`, `>`, `?`, `c` in the git tree) and differ's panel is gone. The renames are in the table above; Find Action lists the new actions.
- **Queue order.** The deltas name requirements that exist only after `file-tree-view` and `git-changes-tree` are archived ("Project tree window", "Tabline offset for the project tree"); `openspec validate` reports them as info until then, and `Depends: git-changes-tree` keeps this change last.
- **Diagnostics in the tree are lost** (neo-tree showed the worst diagnostic per file). `file-tree-view` scopes them out; a follow-up can add them.
- **netrw users** of `:Explore`/`gx` lose them: `gx` is Neovim's own since 0.10 (`vim.ui.open`), `:Explore` has no successor beyond `:edit <dir>`.
- **Stale installs.** Removing specs does not delete `~/.local/share/nvim/lazy/{neo-tree.nvim,differ.nvim,vscode-diff.nvim}`; `:Lazy clean` does, and the test sandboxes link plugins from there, which is harmless.
