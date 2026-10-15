## Why
User report (2026-10-15): the shipped Find Action palette "doesn't quite look how I expected". It should match the approved design (find-action design.md, Proposed H1, and its highlight map) in background colours and in the font of the category column (`Git | Diff`). The user also does not see "recently used".

Kind: bug
Adopt: loop/fix-find-action-match-design

## Evidence
- `evidence/design.png`: the approved design's palette, with a `recently used` section, the selected row Open Differ, and the category column in plain weight.
- `evidence/live.png`: the user's live palette (right half). The selected row's `Git | Diff` is bold and brighter than in the design.
- `lua/gleb/picker/frame.lua:26-37` hard-codes the picker body and selected backgrounds to palette `bg0`/`bg1`; approved H1 instead maps those cells to `NormalFloat`/`PmenuSel`. `lua/gleb/picker/rows.lua:109-112` always applies unselected `PmenuExtra` to a category, while H1 maps the selected category to `PmenuExtraSel`.
- `~/.local/state/nvim/find_action_recent.json` holds one id (`tree.toggle_filesystem`). `lua/gleb/find_action/palette.lua:256` records only palette choices; shortcut dispatch through `lua/gleb/actions/context.lua:75-90` and direct mappings selected by `lua/gleb/actions/apply.lua:30-40` do not record use. The section is drawn only when a recorded action passes the mode/filetype filter (`palette.lua:62-67`).
- `tests/screen/find-action/test_palette.lua:65-72` seeds history directly, and its wide case (`test_palette.lua:109-123`) has no H1 color-mask assertion, so it neither exercises real shortcut recording nor catches background and selected-category attribute drift.

## What Changes
- The live palette matches approved design H1's background groups and category-column weight and colour on selected and unselected rows.
- "recently used" records catalog actions run from configured shortcuts as well as from the palette, then shows the applicable actions in most-recently-used order.
- The reference screenshots compare colours and attributes against the H1 highlight map, so this kind of drift fails a test.

## Impact
- Runtime: `lua/gleb/find_action/palette.lua`, `lua/gleb/find_action/items.lua`, action dispatch in `lua/gleb/actions/context.lua` and `lua/gleb/actions/apply.lua`, and Find Action highlight support in `lua/gleb/picker/frame.lua` and `lua/gleb/picker/rows.lua`.
- Tests: `tests/integration/find-action/test_run.lua`, `tests/screen/find-action/test_palette.lua`, and its reference screenshots.
- Architecture: no module-layout, load-order, or plugin-wiring change.
- Dependencies: no plugin is added, removed, or upgraded.
- Core keymaps: unchanged.
- Out of scope: changing the approved H1 layout, picker breakpoints, action availability filters, shortcut assignment, or other picker sources' appearance.

## Rejected run
Run on `loop/fix-find-action-match-design` was rejected by the judge:
- fix loop exhausted with gates still red: review
- review findings:
  [must-fix] lua/gleb/actions/apply.lua:107-124,231-233 — the global `vim.on_key` recorder adds a catalog action to history whenever a typed key matches its shortcut and the active global mapping's desc, even if the action never runs. The requirement says history records actions that are *run* from a configured shortcut. Reproduced with `make probe`: clear history, open Find Action with `<M-A>`, type `<C-h><Esc>`. `<C-h>` only scrolls the MiniPick query (mode(1) is "n" inside getcharstr), yet history becomes `{ "window.move_left" }` (settings/keymap.json binds `window.move_left` to `<C-h>`). The same happens for any picker or getchar prompt where a typed key collides with a normal/visual catalog shortcut, so actions that never ran show up first under "recently used". Record from the mapping's rhs instead, for example by wrapping `action.mapping` and `action.plug` rhs in `set_mapping`, so recording happens only when the mapping actually executes. Also add an integration case that runs a `mapping`/`plug`-type shortcut: the new test only exercises the `Context.invoke` path (`gR`) and a plugin action, so the on_key path has no test. This is the first review pass; there are no earlier reviews.
  [minor] openspec/changes/fix-find-action-match-design/specs/find-action/spec.md:8-10 — the MODIFIED scenario "Empty query puts recent actions first" drops "persisted" from its THEN. Cross-session persistence is still in the requirement text and in "Recent history keeps the last 20 actions", so
- note: loop: FAIL checkhealth without ERROR: blink.cmp diffview lazy lspconfig luasnip neo-tree nvim-treesitter vim.deprecated vim.health vim.lsp vim.pack vim.treesitter yaml-companion
