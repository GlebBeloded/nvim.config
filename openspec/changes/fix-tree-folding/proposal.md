## Why

Kind: bug

Depends: refactor-tree-shared-core, refactor-split-large-modules

The user (2026-10-19): folding does not work in the Find Usages view ("lsp tree") or the Changes panel ("git
tree"). Each of the three trees grew its own fold code, each with a different subset of keys:

- the project tree has `file_tree.toggle_fold` `za`, `file_tree.close_node` `h` `<BS>`, `file_tree.fold_all`
  `zM`, `file_tree.unfold_all` `zR`, and `l` on `file_tree.open`;
- the Changes panel has only `changes.toggle_fold` `za` (and `<CR>` on a group row);
- the Find Usages view has only `references.fold` `za` (and `<CR>` on a group row).

Every other fold key a Vim user reaches for falls through to native Vim, which has no folds in these
`nofile` buffers.

## Evidence

Reproduced read-only with `make probe` (script kept in the lead's scratch dir as `agent_fold/probe_fold.lua`):
a fresh git repo with `lib/a.lua`, `lib/b.lua`, `src/deep/c.go` and `top.txt` all modified; each tree opened
through its real action (`file_tree.toggle`, `changes.toggle`, `gleb.references.view.open` with three usages),
the cursor put on the `lib` group row, once expanded and once collapsed, and each key fed with
`nvim_feedkeys(…, "mx")`. "nothing" means the buffer lines did not change.

| Key | Project tree | Changes panel | Find Usages |
|---|---|---|---|
| `za`, `<CR>` | toggles | toggles | toggles |
| `zo`, `zc` | nothing, `E490: No fold found` | nothing, E490 | nothing, E490 |
| `zM`, `zR` | fold / unfold all | nothing | nothing |
| `h` | collapses | nothing | nothing |
| `l` | expands a folded folder, but **collapses an open one** (`file_tree.open` toggles) | nothing | nothing |
| `<Left>`, `<Right>` | nothing | nothing | nothing |
| `<M-->`, `<M-=>` (`fold.close_one`, `fold.open_one`) | nothing (native `zc`/`zo` error swallowed) | nothing | nothing |
| `<S-D-->`, `<S-D-=>` (`fold.close_all`, `fold.open_all`) | nothing, `v:errmsg` E490 (ufo) | nothing, E490 | nothing, E490 |

Task 1 reproduction with the real mappings differed for Find Usages only: `zc` and `zo` left the rows unchanged
but also left `v:errmsg` empty, rather than setting E490. All other tested results matched this table.

Code: `git/changes/view.lua` (`visible_rows`, `toggle_fold`), `references/view.lua` (`visible_nodes`, `fold`)
and `file_tree/view.lua` (`close_node`, `toggle_fold`, `fold_all`, `unfold_all`) each flatten rows and track fold
state separately (`collapsed[fold_id]`, `folded[node.id]`, `expanded[path]`); `folding/actions.lua` runs native
`zo`/`zc` and ufo's `openAllFolds`/`closeAllFolds`, which know nothing about these trees.

## What Changes

- **Shared tree component `lua/gleb/ui/tree/`** (design.md, Decisions 1–4): a pure model (nodes with stable ids,
  parent/children, foldable and pinned flags, fold state by id, flatten to rows with depth, selection carry-over
  by id), the fold verbs (close, open, toggle, fold all, unfold all) written once, a thin view helper (buffer
  lines, extmark namespace, cursor placement by id) and a per-buffer registry. The project tree, the Changes
  panel and the Find Usages view adopt it; their row text, glyphs, colours, ordering, refresh and open
  behaviour stay as they are.
- **The same fold keys in all three trees**, as view-scoped actions bound in `settings/keymap.json`:
  - fold: `h`, `<Left>`, `zc` — collapse the open group under the cursor; on a leaf or a folded group,
    collapse its parent and move the cursor to it (today's `file_tree.close_node`);
  - unfold: `l`, `<Right>`, `zo` — expand a folded group; on an open group move the cursor to its first
    child; on a leaf do nothing;
  - `za` toggles (unchanged), `zM` folds every group, `zR` unfolds every group, `<CR>` on a group row toggles
    (unchanged).
  - New actions: `file_tree.expand_node`; `changes.close_node`, `changes.expand_node`, `changes.fold_all`,
    `changes.unfold_all`; `references.close_node`, `references.expand_node`, `references.fold_all`,
    `references.unfold_all`. Existing `file_tree.close_node` gains `<Left>` and `zc`; `file_tree.open` loses `l`
    (now `<CR>` `o`).
- **Global fold actions act on the tree** when a tree buffer is current: `fold.close_one` `<M-->` = fold,
  `fold.open_one` `<M-=>` = unfold, `fold.close_all` `<S-D-->` = fold all, `fold.open_all` `<S-D-=>` = unfold
  all; no E490 in a tree buffer. Elsewhere they keep their current behaviour.
- No visual change: rows and glyphs are as today (design.md, Renders).
- No plugin dependency is added, removed or upgraded.

## Capabilities

### New Capabilities

- `ui`: the shared tree component (model, fold verbs, selection carry-over, registry).

### Modified Capabilities

- `file-tree`: added "Project tree unfold and fold keys"; modified "Project tree keys" (its key list: `l` moves
  from `file_tree.open` to `file_tree.expand_node`, `<Left>` `zc` join `file_tree.close_node`), copied whole.
- `git`: added "Changes panel fold keys"; modified "Changes panel keys" (its key list), copied whole.
- `references`: added "Find Usages fold keys"; modified "Find Usages navigation keys" (its key list and the
  scenario "View keys come from the keymap file"), copied whole.
- `folding`: added "Fold actions in tree buffers".

## Impact

- Code: new `lua/gleb/ui/tree/{model,fold,view,init}.lua`; `file_tree/view.lua` (or the `file_tree/folds.lua`
  that `refactor-split-large-modules` extracts), `file_tree/actions.lua`, `git/changes/{view,init,actions}.lua`,
  `references/{view,actions}.lua`, `folding/actions.lua`, `settings/keymap.json`.
- Tests: unit `tests/unit/ui/test_tree.lua`; integration `tests/integration/file-tree/test_project_tree.lua`,
  `tests/integration/git/test_changes.lua`, `tests/integration/references/test_keys.lua`,
  `tests/integration/folding/test_shortcuts.lua`, `tests/integration/ui/test_tree_buffers.lua`.
- Plugins: none. nui.nvim's `NuiTree` (installed as a dependency; 2.1k stars, last commit 2026-08-20) and
  snacks.nvim's explorer tree (8.2k stars, last commit 2026-05-25, not installed) were compared; design.md
  Decision 1 says why neither is used.
- Core keymaps: no global lhs changes; `<M-->`, `<M-=>`, `<S-D-->`, `<S-D-=>` keep their lhs and gain tree
  behaviour. View-local keys change as listed above (user decision below).
- Unchanged scenarios:
  - `file-tree: Project tree h on a file collapses its folder` still holds: `h` stays on `file_tree.close_node`,
    whose behaviour is the shared fold verb.
  - `file-tree: h on a nested file closes its nest` still holds: a nest child's parent is its nest parent in the
    shared model, so the fold verb collapses the nest and selects the parent.
  - `file-tree: Project tree Enter toggles a folder` and `file-tree: Enter on a nest parent opens the file` still
    hold: `<CR>` stays on `file_tree.open`, unchanged.
  - `file-tree: Project tree zM collapses every folder`, `file-tree: Project tree zR expands every folder`,
    `file-tree: Project tree unfold all stops at the row limit` and `file-tree: Fold all and unfold all include
    nests` still hold: `zM`/`zR` keep their actions; the root stays pinned open and the 5000-row bound stays in
    the project tree's expansion adapter.
  - `git: Changes panel za folds a nest` and `git: Changes panel Enter folds a directory` still hold: `za` and
    `<CR>` keep their actions, now backed by the shared toggle.
  - `references: za folds a group` and `references: Return opens a usage at its position` still hold.
  - `folding: Fold keys invoke registered actions` and `folding: Fold keys without a fold do nothing` still hold:
    outside a tree buffer the fold actions run exactly as today.
  - The diffview file panel's own `h`/`l` keys (`diffview.close_fold`, `diffview.select_entry`, `git` spec) are
    unchanged: diffview's panel is not one of the three trees.
  - `diff: Diff view zo opens a fold in both windows` still holds: `diff.expand_fold` is scoped to `gleb-diff`,
    which is not a tree buffer.
  - `diff: Diff view keys stay native outside view windows` still holds: the new `zo` bindings are buffer-local to
    the three tree filetypes, so native `zo` in a file window is untouched.
  - `picker: Input prompt ignores a blank query` still holds: `<CR>` bindings change in no picker or prompt; only
    tree buffers gain keys.
  - `shortcuts: Ctrl+Return reaches Neovim as <C-CR> from a real key press` still holds: no terminal-layer key or
    `<CR>` binding changes.
  - `shortcuts: Cmd+Shift+- and Cmd+Shift+= reach Neovim as <S-D--> and <S-D-=> from a real key press` still
    holds: the `fold.close_all`/`fold.open_all` lhs stay `<S-D-->`/`<S-D-=>`; only their behaviour in tree buffers
    changes.
- Out of scope:
  - Changing row glyphs (references keeps `▸`/`▾`, the other two keep U+F460/U+F47C); unifying them would be a
    visible change for its own proposal.
  - Counts on the fold keys inside trees (a count is ignored there).
  - The new Branch and Comments trees of `git-changes-tabs` and `pr-comments-view`; they adopt `ui/tree` in
    their own changes.
  - Moving the tree buffers' remaining keys (open, stage, preview) into shared actions.

## Decision (user, 2026-10-19)

- "I have noticed that folding doesn't work in lsp/git tree. Make sure same reusable tree code is used, I can
  fold unfold nodes there"
- "I want h(left), to fold, l(right) to unfold" — `h`/`<Left>` fold and `l`/`<Right>` unfold are the primary
  fold keys in all three trees; `za`, `zM`, `zR` and the global fold actions stay as planned.

## Agent decisions

- `l` on a leaf does nothing in every tree (IntelliJ: Right on a leaf does nothing). In the project tree this
  drops today's "`l` opens the file"; `<CR>` and `o` still open it. No spec requires `l` to open a file.
- `za` on a leaf collapses its parent and selects it in every tree (today's project-tree rule), so the Changes
  panel and Find Usages view gain it on file and usage rows, where `za` did nothing.
- `zM` folds every foldable group, including the Changes panel's `Changes`/`Unversioned Files` roots and the
  Find Usages scope rows; the project tree's root row is pinned open, as today.
- Per-tree action ids (not one shared `tree.*` set), so each tree's "keys come from the keymap file" scenario
  keeps its `<area>.*` rule and each action keeps its `<Category>: <Title>` desc; the ids are built by one
  factory in `ui/tree` and a `ui` scenario pins that their keys are identical.
- A new `ui` capability holds the component's pure contract (`lua/gleb/ui/` module, rule 1.3 unit tests).
