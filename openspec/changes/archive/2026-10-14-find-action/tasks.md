## 1. Wire the Find Action entry point
Scenarios: `find-action: Find Action opens from its shortcut`, `find-action: Find Action is registered as an action`
- [x] 1.1 Write the tests in `tests/integration/find-action/test_open.lua` and run `make test FILE=tests/integration/find-action/test_open.lua`, seeing both scenarios fail
- [x] 1.2 Add the typed `lua/gleb/find_action/` entry point and action list, register the feature actions in `init.lua`, and map `<M-A>` through `settings/keymap.json`
- [x] 1.3 Run `make test FILE=tests/integration/find-action/test_open.lua` and see both scenarios pass

## Agent decisions

- Start the entry-point picker with an empty item list because row population belongs to the later rendering and ordering tasks.
- Pass resolved toggle state into row formatting so the formatter stays pure and does not call action callbacks.
- Store history in most-recent-first order, moving a repeated action to the front so use order stays stable across sessions.
- Fuzzy-match case-insensitive subsequences within each field independently so characters cannot match across unrelated metadata.
- Keep the backing action on each picker row so reveal and assignment decisions use registry metadata rather than rendered text.
- Append a newly assigned lhs once so existing shortcuts remain available without creating duplicates.
- Identify adapter-owned actions by their established action-area prefixes so the palette can name the plugin reopen boundary without loading plugins.
- Keep a fourteen-row Find Action result area at every width so responsive layouts change fields without changing the approved H1 capacity.
- Reduce the compact Find Action hint to its two physical keys so it preserves both operations without labels.
- Style assignment keys and choices with existing semantic highlight groups so the float follows the active colorscheme.
- Use Cmd+D as the workflow's free assignment because its kitty-protocol key is unbound and remains observable across restart.
- Keep the task-9 mapping cell generic (`fn`) because exact Find Action callback identity belongs to task 10.
- Give self-context-capturing actions an explicit mapping callback so Find Action keeps registry assignment while exposing its exact entry point.
- Observe stack pickers by their active source name over RPC so real-byte tests assert the opened UI without replacing mappings.
- Run the physical Find Action mapping directly and stop its stack after assertion so the blocking picker cannot leak into the next case.
- Use `ai.search` and `ai.vibe` in the AI category so the stable IDs follow the feature-action convention while the titles retain the 99 product name.
- Expose stable named prompt callbacks from the entry-keymap module so direct mappings and registry actions share one invocation path.
- Keep task 15 as a regression-test correction because task 14 already registered the required `n`/`x` mappings and left select mode untouched.
- Compose e2e references from exact zellij rows so every workflow capture is fully compared without duplicating unchanged palette rows.
- Schedule actionable-row selection from the matcher and read the latest matches so rapid query replacements cannot apply a stale index.
- Override Find Action's native movement keys to cycle only action rows because section rows are display-only.

## 2. Render action rows
Scenarios: `find-action: Rows show action metadata`, `find-action: Rows fall back to Vim notation`, `find-action: Toggle rows show state glyphs`
- [x] 2.1 Write the tests in `tests/unit/find-action/test_rows.lua` and run `make test FILE=tests/unit/find-action/test_rows.lua`, seeing all three scenarios fail
- [x] 2.2 Add pure row and physical-label formatting for titles, first shortcuts, categories, and toggle glyphs
- [x] 2.3 Run `make test FILE=tests/unit/find-action/test_rows.lua` and see all three scenarios pass

## 3. Order and match actions
Scenarios: `find-action: Empty query puts recent actions first`, `find-action: Recent history keeps the last 20 actions`, `find-action: Query matches all searchable fields`
- [x] 3.1 Write the tests in `tests/unit/find-action/test_items.lua` and run `make test FILE=tests/unit/find-action/test_items.lua`, seeing all three scenarios fail
- [x] 3.2 Add pure item matching and ordering plus a last-20 MRU store at `stdpath("state")/find_action_recent.json`
- [x] 3.3 Run `make test FILE=tests/unit/find-action/test_items.lua` and see all three scenarios pass

## 4. Reveal hidden actions
Scenarios: `find-action: Hidden and unavailable actions start absent`, `find-action: Show hidden reveals a separate tier`, `find-action: Hidden commands cannot be assigned`
- [x] 4.1 Write the tests in `tests/integration/find-action/test_hidden.lua` and run `make test FILE=tests/integration/find-action/test_hidden.lua`, seeing all three scenarios fail
- [x] 4.2 Filter against the captured context, add the query-preserving `<M-A>` hidden tier and separator, and reject assignment for hidden Ex commands
- [x] 4.3 Run `make test FILE=tests/integration/find-action/test_hidden.lua` and see all three scenarios pass

## 5. Run actions in their opening context
Scenarios: `find-action: Regular action runs like its shortcut`, `find-action: Toggle changes without closing the palette`, `find-action: Visual palette preserves the selection`
- [x] 5.1 Write the tests in `tests/integration/find-action/test_run.lua` and run `make test FILE=tests/integration/find-action/test_run.lua`, seeing all three scenarios fail
- [x] 5.2 Connect palette selection and toggle handling to the captured action context while preserving the selected row and visual selection
- [x] 5.3 Run `make test FILE=tests/integration/find-action/test_run.lua` and see all three scenarios pass

## 6. Assign shortcuts from the palette
Scenarios: `find-action: Assign float captures a free shortcut`, `find-action: Assignment can be cancelled`, `find-action: Conflict choices have distinct outcomes`, `find-action: Saved shortcut applies immediately`, `find-action: Adapter assignment reports deferred application`
- [x] 6.1 Write the tests in `tests/integration/find-action/test_assign.lua` and run `make test FILE=tests/integration/find-action/test_assign.lua`, seeing all five scenarios fail
- [x] 6.2 Add the modal capture float, conflict controls, store-and-reapply flow, and adapter reopen notice
- [x] 6.3 Run `make test FILE=tests/integration/find-action/test_assign.lua` and see all five scenarios pass

## 7. Pin Find Action reference screens
Scenarios: `find-action: Wide palette matches reference screenshots`, `find-action: Compact palette matches reference screenshot`, `find-action: Narrow palette matches reference screenshot`, `find-action: Conflict assignment matches reference screenshot`, `find-action: Free assignment matches reference screenshot`
- [x] 7.1 Write the screen tests in `tests/screen/find-action/test_palette.lua` from the approved design renders and run `make test FILE=tests/screen/find-action/test_palette.lua`, seeing all five scenarios fail
- [x] 7.2 Apply the approved picker layout, hint text, responsive fields, state highlights, and assignment-float styling
- [x] 7.3 Run `make test FILE=tests/screen/find-action/test_palette.lua` and see all five scenarios pass

## 8. Persist the real-key workflow
Scenarios: `find-action: Physical Find Action workflow persists an assignment`
- [x] 8.1 Write the sandbox test in `tests/e2e/find-action/test_e2e.lua` and run `make e2e FILE=tests/e2e/find-action/test_e2e.lua CASE="Physical Find Action workflow persists an assignment"`, seeing it fail
- [x] 8.2 Drive open, search, run, physical-key assignment, reuse, restart, and screenshot comparison through the existing Alacritty/zellij harness
- [x] 8.3 Run `make e2e FILE=tests/e2e/find-action/test_e2e.lua CASE="Physical Find Action workflow persists an assignment"` in the sandbox VM and see it pass

## 9. Extend the shortcut-table route
Scenarios: `shortcuts: Alacritty bindings match the shortcut table`, `shortcuts: Every Alacritty chars binding can match a key press`, `shortcuts: zellij routes every shortcut as in the table`, `shortcuts: Locked mode passes every shortcut through`, `shortcuts: Neovim receives the key in the table`
- [x] 9.1 Add the Cmd+Shift+A row to the shortcut-table fixture and run `make test FILE=tests/chain/shortcuts/test_chain.lua`, seeing the affected scenarios fail
- [x] 9.2 Add the `Cmd+Shift+A` `\eA` Alacritty binding and route it unchanged through zellij
- [x] 9.3 Run `make test FILE=tests/chain/shortcuts/test_chain.lua` and see all five scenarios pass

## 10. Match the Find Action mapping
Scenarios: `shortcuts: Neovim mappings match the table`
- [x] 10.1 Extend `tests/chain/shortcuts/test_chain.lua` for the Find Action callback and run `make test FILE=tests/chain/shortcuts/test_chain.lua CASE="Neovim mappings match the table"`, seeing it fail
- [x] 10.2 Complete the shortcut-table mapping entry for `find_action.open`
- [x] 10.3 Run `make test FILE=tests/chain/shortcuts/test_chain.lua CASE="Neovim mappings match the table"` and see it pass

## 11. Deliver Find Action through real zellij
Scenarios: `shortcuts: Cmd+Shift+A opens Find Action through real zellij`
- [x] 11.1 Write the test in `tests/stack/shortcuts/test_stack.lua` and run `make test FILE=tests/stack/shortcuts/test_stack.lua CASE="Cmd+Shift+A opens Find Action through real zellij"`, seeing it fail
- [x] 11.2 Make the stack harness observe the palette opened by the delivered Cmd+Shift+A bytes
- [x] 11.3 Run `make test FILE=tests/stack/shortcuts/test_stack.lua CASE="Cmd+Shift+A opens Find Action through real zellij"` and see it pass

## 12. Deliver Find Action from a physical shortcut
Scenarios: `shortcuts: Cmd+Shift+A opens Find Action from a real key press`
- [x] 12.1 Write the sandbox test in `tests/e2e/shortcuts/test_e2e.lua` and run `make e2e FILE=tests/e2e/shortcuts/test_e2e.lua CASE="Cmd+Shift+A opens Find Action from a real key press"`, seeing it fail
- [x] 12.2 Extend the e2e recorder to observe the palette after the real Cmd+Shift+A key event
- [x] 12.3 Run `make e2e FILE=tests/e2e/shortcuts/test_e2e.lua CASE="Cmd+Shift+A opens Find Action from a real key press"` in the sandbox VM and see it pass

## 13. Replace the normal 99 menu with actions
Scenarios: `ai: Menu shows prompt`, `ai: Menu s opens search prompt`, `ai: Menu v opens vibe prompt`, `ai: Menu ignores other keys`
- [x] 13.1 Update the cases in `tests/integration/ai/test_prompt_keys.lua` for the action-based entry points and absent normal `<A-9>` menu, then run `make test FILE=tests/integration/ai/test_prompt_keys.lua`, seeing the four changed scenarios fail
- [x] 13.2 Add `lua/gleb/ai/actions.lua`, register 99 Search and 99 Vibe, and remove the normal-mode `<A-9>` menu
- [x] 13.3 Run `make test FILE=tests/integration/ai/test_prompt_keys.lua` and see all four scenarios pass

## 14. Preserve direct 99 prompt mappings
Scenarios: `ai: Shift-Enter opens vibe prompt`, `ai: Visual Alt-9 opens visual prompt`, `ai: Visual Shift-Enter opens visual prompt`
- [x] 14.1 Update the preserved mapping cases in `tests/integration/ai/test_prompt_keys.lua` and run `make test FILE=tests/integration/ai/test_prompt_keys.lua`, seeing the changed expectations fail before the entry-keymap rewrite
- [x] 14.2 Keep the normal Shift-Enter and visual Alt-9 and Shift-Enter paths while separating their callbacks for action reuse
- [x] 14.3 Run `make test FILE=tests/integration/ai/test_prompt_keys.lua` and see all three scenarios pass

## 15. Keep 99 mapping scope and silence
Scenarios: `ai: Entry mappings are silent`, `ai: Select mode keeps its default behavior`
- [x] 15.1 Update the cases in `tests/unit/ai/test_entry_keymaps.lua` and run `make test FILE=tests/unit/ai/test_entry_keymaps.lua`, seeing both changed scenarios fail
- [x] 15.2 Register only the specified silent normal and visual mappings and leave select mode untouched
- [x] 15.3 Run `make test FILE=tests/unit/ai/test_entry_keymaps.lua` and see both scenarios pass

## 16. Run the initial visual action from its section row
Scenarios: `find-action: Visual palette preserves the selection`
- [x] 16.1 Run `make test FILE=tests/integration/find-action/test_run.lua CASE="Visual palette preserves the selection"` against the real `<M-A>` picker populated with the visual action, press `<CR>`, and see it fail because the initial section row has no action
- [x] 16.2 Make the smallest Find Action choice change so `<CR>` on an initial section row resolves the following action by the picker's current match index, preserving the captured visual selection and the approved section-row highlight
- [x] 16.3 Run `make test FILE=tests/integration/find-action/test_run.lua CASE="Visual palette preserves the selection"` and `make test FILE=tests/screen/find-action/test_palette.lua`, and see them pass

## 17. Keep selection on actionable rows
Scenarios: `find-action: Selection skips section rows`, `find-action: Wide palette matches reference screenshots`
- [x] 17.1 Write the test `find-action: Selection skips section rows` in `tests/integration/find-action/test_open.lua`, driving the real `<M-A>` picker with populated visible and hidden actions through open, query, and Show hidden; tighten `tests/screen/find-action/test_palette.lua` to require the approved first-action highlight, then run both named cases and see them fail
- [x] 17.2 Make the smallest `lua/gleb/find_action/palette.lua` change that selects the first actionable match after start and every item or match replacement, so Enter, `<M-}>`, and navigation agree, then regenerate only the affected wide references
- [x] 17.3 Run `make test FILE=tests/integration/find-action/test_open.lua CASE="Selection skips section rows"` and `make test FILE=tests/screen/find-action/test_palette.lua CASE="Wide palette matches reference screenshots"` and see them pass
