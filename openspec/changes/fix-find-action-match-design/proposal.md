## Why
User report (2026-10-15): the shipped Find Action palette "doesn't quite look how I expected". It should match the approved design (find-action design.md, Proposed H1, and its highlight map) in background colours and in the font of the category column (`Git | Diff`). The user also does not see "recently used".

Kind: bug
Adopt: loop/fix-find-action-match-design

## Evidence
- `evidence/design.png`: the approved design's palette, with a `recently used` section, the selected row Open Differ, and the category column in plain weight.
- `evidence/live.png`: the user's live palette (right half). The selected row's `Git | Diff` is bold and brighter than in the design.
- Sampled colours that match in both images: body `#44403d`, selected row `#59524d`, category `#a59a86`. Find which backgrounds differ by comparing a live render with design.md H1 (row by row, highlight map included) rather than trusting these samples.
- Recently used: `~/.local/state/nvim/find_action_recent.json` holds one id (`tree.toggle_filesystem`). Only palette runs are recorded (`lua/gleb/find_action/palette.lua:256`), so actions run by shortcut never appear. The section is drawn only when a recent action passes the mode/filetype filter (`palette.lua:62-67`).
- Highlights: `lua/gleb/picker/frame.lua:29-37`, `lua/gleb/picker/rows.lua:60-111`. The design's selected-row groups are PmenuSel/PmenuExtraSel (design.md H1 highlight map).

## What Changes
- The live palette matches design H1: backgrounds, and the category column's weight and colour on selected and unselected rows.
- "recently used" shows the user's recent actions. Recommendation: record every action run through the registry (shortcut or palette), not only palette runs.
- The reference screenshots compare colours and attributes against the H1 highlight map, so this kind of drift fails a test.

## Impact
- Code: `lua/gleb/find_action/`, `lua/gleb/picker/` (highlights), action dispatch in `lua/gleb/actions/` (recording).
- Tests: find-action screen and e2e references.

## Rejected run
Run on `loop/fix-find-action-match-design` was rejected by the judge:
- fix loop exhausted with gates still red: review
- review findings:
  [must-fix] lua/gleb/actions/apply.lua:107-124,231-233 — the global `vim.on_key` recorder adds a catalog action to history whenever a typed key matches its shortcut and the active global mapping's desc, even if the action never runs. The requirement says history records actions that are *run* from a configured shortcut. Reproduced with `make probe`: clear history, open Find Action with `<M-A>`, type `<C-h><Esc>`. `<C-h>` only scrolls the MiniPick query (mode(1) is "n" inside getcharstr), yet history becomes `{ "window.move_left" }` (settings/keymap.json binds `window.move_left` to `<C-h>`). The same happens for any picker or getchar prompt where a typed key collides with a normal/visual catalog shortcut, so actions that never ran show up first under "recently used". Record from the mapping's rhs instead, for example by wrapping `action.mapping` and `action.plug` rhs in `set_mapping`, so recording happens only when the mapping actually executes. Also add an integration case that runs a `mapping`/`plug`-type shortcut: the new test only exercises the `Context.invoke` path (`gR`) and a plugin action, so the on_key path has no test. This is the first review pass; there are no earlier reviews.
  [minor] openspec/changes/fix-find-action-match-design/specs/find-action/spec.md:8-10 — the MODIFIED scenario "Empty query puts recent actions first" drops "persisted" from its THEN. Cross-session persistence is still in the requirement text and in "Recent history keeps the last 20 actions", so
- note: loop: FAIL checkhealth without ERROR: blink.cmp diffview lazy lspconfig luasnip neo-tree nvim-treesitter vim.deprecated vim.health vim.lsp vim.pack vim.treesitter yaml-companion
