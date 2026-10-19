## Context

Three trees render rows into a `nofile` buffer and each owns its fold code:

- Project tree (`file_tree/view.lua`, after `refactor-split-large-modules` its `folds.lua`): rows come from
  `file_tree/model.rows(tree, expanded, …, expanded_nests)`, a lazily scanned filesystem with compact folder
  chains, nests and a 5000-row bound; fold state is `expanded[relative path]` (persisted in `expanded.json`) and
  `expanded_nests`. Verbs: `toggle_fold`, `close_node`, `fold_all`, `unfold_all`; `open` doubles as unfold.
- Changes panel (`git/changes/view.lua`): `model.rows` builds every row up front; `visible_rows` hides rows below
  `collapsed[fold_id]`; only `toggle_fold`.
- Find Usages (`references/tree.lua` builds nodes with `id`/`parent_id`/`depth`; `references/view.lua`
  `visible_nodes` hides below `folded[id]`); only `fold` (toggle).

`folding/actions.lua` runs native `zo`/`zc` and ufo's all-fold functions, which do nothing (or set E490) in these
buffers. The proposal's Evidence table shows the per-tree, per-key result.

`refactor-tree-shared-core` (debounce helper, neutral status/nesting module, `run_git`) and
`refactor-split-large-modules` (file tree `folds.lua`, references formatting/preview split) land first and are pure
moves; this change builds on their file layout and duplicates neither.

## Goals / Non-Goals

Goals:
- One tree component (`lua/gleb/ui/tree/`) whose model, fold verbs, selection carry-over and buffer registry all
  three trees use.
- The same fold keys and semantics in every tree; global fold actions work on trees.

Non-Goals:
- Changing row text, glyphs, colours, ordering, refresh, diff/preview or open behaviour.
- Moving the trees' own renderers (icons, git colours, stats, tags) into the component.
- Persisting Changes or Find Usages fold state beyond the view's life (as today).

## Decisions

1. **Own small component; no NuiTree or snacks tree.**
   - Proposed A: `nui.nvim` `NuiTree` (installed as a dependency, 2.1k stars, last commit 2026-08-20). It stores
     nodes by id with `expand`/`collapse` and renders through `NuiLine`. It owns rendering (every line through
     `prepare_node`/`NuiLine`), so the three width-aware renderers (right-aligned stats, tags, truncation) and the
     project tree's lazy scan, compact chains, nests and 5000-row bound would be rewritten into it; it has no
     fold verbs (parent fold, first-child step, fold all with selection) and no selection carry-over, which are
     the actual bug.
   - Proposed B: snacks.nvim explorer (8.2k stars, last commit 2026-05-25): its tree is internal to the picker,
     not a public component, and snacks is not installed.
   - Proposed C (picked): a pure model + verbs of about 200 lines with no plugin requires (rule 1.3), plus a thin
     view helper. The renderers stay where they are and receive the visible rows.
2. **Model (`ui/tree/model.lua`, pure).** `Node = { id, parent?, children, foldable, pinned?, open_by_default }`.
   `new(nodes)`, `rebuild(m, nodes)` keeps `folds[id]` only for ids still present, `set_open(m, id, open)`,
   `rows(m)` → `{ id, depth, node }[]` depth first, skipping descendants of folded groups. Feature payload rides
   on `node.data`. Built from: Changes `model.rows` (ids are today's `row_key`), Find Usages `tree.build` (ids are
   today's node ids), project tree rows (ids are absolute paths; nest children's parent is the nest parent).
3. **Fold verbs (`ui/tree/fold.lua`, pure)** take the model and the selected id and return the new selected id:
   `close`, `open`, `toggle`, `close_all`, `open_all` (semantics in the `ui` spec, matching today's
   `file_tree.close_node`, `toggle_fold`, `fold_all`). Expansion goes through an adapter hook
   `expand(node) -> boolean` so the project tree keeps its lazy scan, the 5000-row bound and its WARN
   notifications; Changes and Find Usages use the default (set fold state). The project tree's root row is
   `pinned`; `close_all` there keeps today's "root open, cursor on the top-level row" result.
4. **View helper and registry (`ui/tree/view.lua`, `ui/tree/init.lua`).** `attach(buf, tree)` registers the buffer
   (cleared on `BufWipeout`); `get(buf)`; `draw(tree, render_rows)` writes lines through the feature renderer and
   then places the cursor by id: same id → its row; hidden → nearest visible ancestor; gone → the feature's
   fallback (`select_file` in Changes, clamp in Find Usages, `restore_cursor` in the project tree), so today's
   cursor behaviour is kept.
5. **Actions.** `ui/tree/actions.lua` exports `fold_actions({ area, category, ft, toggle_id? })` returning
   `gleb.Action[]` for `<area>.close_node`, `expand_node`, `fold_all`, `unfold_all` and the toggle (existing ids
   `file_tree.toggle_fold`, `changes.toggle_fold`, `references.fold` keep their ids and titles). Each feature's
   `actions.lua` appends them (rule 1.9). Titles: `Collapse Node`, `Expand Node`, `Fold All`, `Unfold All`;
   `file_tree.close_node` keeps `Close Node`. Keys (rule 3.1, `settings/keymap.json`):

   | Action | Keys |
   |---|---|
   | `<area>.close_node` | `h` `<Left>` `zc` (project tree also `<BS>`) |
   | `<area>.expand_node` | `l` `<Right>` `zo` |
   | toggle | `za` |
   | `<area>.fold_all` / `unfold_all` | `zM` / `zR` |
   | `file_tree.open` | `<CR>` `o` (drops `l`) |

   Scope conflicts checked: in `gleb-file-tree` `l` was `file_tree.open` (moved), `h` was `file_tree.close_node`
   (kept); in `gleb-changes` and `gleb-references` none of `h l <Left> <Right> zc zo zM zR` is bound today.
6. **Global fold actions.** `folding/actions.lua` checks `require("gleb.ui.tree").get(0)` first; with a tree it
   runs the verb and returns, otherwise it runs today's guarded `zo`/`zc` and ufo calls. `ui/tree` loads no
   plugin, so this adds no lazy-plugin require on a hot path (rule 2.5).

## Renders

No visual change. Every row keeps its text, glyph (project tree and Changes U+F460/U+F47C, Find Usages `▸`/`▾`)
and highlight groups; only which rows are listed and where the cursor sits change on the fold keys. Those are
pinned by integration scenarios on row lists and cursor rows, and the existing screen scenarios
(`file-tree: Project tree matches the approved render`, `references: Wide view matches reference screenshot`, …)
must stay green unchanged.

## Risks / Trade-offs

- `l` no longer opens a file in the project tree (agent decision; `<CR>`/`o` do). If the user relies on it, add
  `l` back as "open a leaf" in `expand_node` — a one-line verb option.
- Rebuilding the project tree's rows through the model must stay within its 5000-row and large-folder bounds;
  the model is built from the rows `file_tree/model.rows` already returns, adding one O(rows) pass.
- Fold state by id: a Changes row id that changes on rename (`root:path`) loses its fold, as today.
