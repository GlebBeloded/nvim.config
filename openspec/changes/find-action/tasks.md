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
- [ ] 5.1 Write the tests in `tests/integration/find-action/test_run.lua` and run `make test FILE=tests/integration/find-action/test_run.lua`, seeing all three scenarios fail
- [ ] 5.2 Connect palette selection and toggle handling to the captured action context while preserving the selected row and visual selection
- [ ] 5.3 Run `make test FILE=tests/integration/find-action/test_run.lua` and see all three scenarios pass

## 6. Assign shortcuts from the palette
Scenarios: `find-action: Assign float captures a free shortcut`, `find-action: Assignment can be cancelled`, `find-action: Conflict choices have distinct outcomes`, `find-action: Saved shortcut applies immediately`, `find-action: Adapter assignment reports deferred application`
- [ ] 6.1 Write the tests in `tests/integration/find-action/test_assign.lua` and run `make test FILE=tests/integration/find-action/test_assign.lua`, seeing all five scenarios fail
- [ ] 6.2 Add the modal capture float, conflict controls, store-and-reapply flow, and adapter reopen notice
- [ ] 6.3 Run `make test FILE=tests/integration/find-action/test_assign.lua` and see all five scenarios pass

## 7. Pin Find Action reference screens
Scenarios: `find-action: Wide palette matches reference screenshots`, `find-action: Compact palette matches reference screenshot`, `find-action: Narrow palette matches reference screenshot`, `find-action: Conflict assignment matches reference screenshot`, `find-action: Free assignment matches reference screenshot`
- [ ] 7.1 Write the screen tests in `tests/screen/find-action/test_palette.lua` from the approved design renders and run `make test FILE=tests/screen/find-action/test_palette.lua`, seeing all five scenarios fail
- [ ] 7.2 Apply the approved picker layout, hint text, responsive fields, state highlights, and assignment-float styling
- [ ] 7.3 Run `make test FILE=tests/screen/find-action/test_palette.lua` and see all five scenarios pass

## 8. Persist the real-key workflow
Scenarios: `find-action: Physical Find Action workflow persists an assignment`
- [ ] 8.1 Write the sandbox test in `tests/e2e/find-action/test_e2e.lua` and run `make e2e FILE=tests/e2e/find-action/test_e2e.lua CASE="Physical Find Action workflow persists an assignment"`, seeing it fail
- [ ] 8.2 Drive open, search, run, physical-key assignment, reuse, restart, and screenshot comparison through the existing Alacritty/zellij harness
- [ ] 8.3 Run `make e2e FILE=tests/e2e/find-action/test_e2e.lua CASE="Physical Find Action workflow persists an assignment"` in the sandbox VM and see it pass

## 9. Extend the shortcut-table route
Scenarios: `shortcuts: Alacritty bindings match the shortcut table`, `shortcuts: Every Alacritty chars binding can match a key press`, `shortcuts: zellij routes every shortcut as in the table`, `shortcuts: Locked mode passes every shortcut through`, `shortcuts: Neovim receives the key in the table`
- [ ] 9.1 Add the Cmd+Shift+A row to the shortcut-table fixture and run `make test FILE=tests/chain/shortcuts/test_chain.lua`, seeing the affected scenarios fail
- [ ] 9.2 Add the `Cmd+Shift+A` `\eA` Alacritty binding and route it unchanged through zellij
- [ ] 9.3 Run `make test FILE=tests/chain/shortcuts/test_chain.lua` and see all five scenarios pass

## 10. Match the Find Action mapping
Scenarios: `shortcuts: Neovim mappings match the table`
- [ ] 10.1 Extend `tests/chain/shortcuts/test_chain.lua` for the Find Action callback and run `make test FILE=tests/chain/shortcuts/test_chain.lua CASE="Neovim mappings match the table"`, seeing it fail
- [ ] 10.2 Complete the shortcut-table mapping entry for `find_action.open`
- [ ] 10.3 Run `make test FILE=tests/chain/shortcuts/test_chain.lua CASE="Neovim mappings match the table"` and see it pass

## 11. Deliver Find Action through real zellij
Scenarios: `shortcuts: Cmd+Shift+A opens Find Action through real zellij`
- [ ] 11.1 Write the test in `tests/stack/shortcuts/test_stack.lua` and run `make test FILE=tests/stack/shortcuts/test_stack.lua CASE="Cmd+Shift+A opens Find Action through real zellij"`, seeing it fail
- [ ] 11.2 Make the stack harness observe the palette opened by the delivered Cmd+Shift+A bytes
- [ ] 11.3 Run `make test FILE=tests/stack/shortcuts/test_stack.lua CASE="Cmd+Shift+A opens Find Action through real zellij"` and see it pass

## 12. Deliver Find Action from a physical shortcut
Scenarios: `shortcuts: Cmd+Shift+A opens Find Action from a real key press`
- [ ] 12.1 Write the sandbox test in `tests/e2e/shortcuts/test_e2e.lua` and run `make e2e FILE=tests/e2e/shortcuts/test_e2e.lua CASE="Cmd+Shift+A opens Find Action from a real key press"`, seeing it fail
- [ ] 12.2 Extend the e2e recorder to observe the palette after the real Cmd+Shift+A key event
- [ ] 12.3 Run `make e2e FILE=tests/e2e/shortcuts/test_e2e.lua CASE="Cmd+Shift+A opens Find Action from a real key press"` in the sandbox VM and see it pass

## 13. Replace the normal 99 menu with actions
Scenarios: `ai: Menu shows prompt`, `ai: Menu s opens search prompt`, `ai: Menu v opens vibe prompt`, `ai: Menu ignores other keys`
- [ ] 13.1 Update the cases in `tests/integration/ai/test_prompt_keys.lua` for the action-based entry points and absent normal `<A-9>` menu, then run `make test FILE=tests/integration/ai/test_prompt_keys.lua`, seeing the four changed scenarios fail
- [ ] 13.2 Add `lua/gleb/ai/actions.lua`, register 99 Search and 99 Vibe, and remove the normal-mode `<A-9>` menu
- [ ] 13.3 Run `make test FILE=tests/integration/ai/test_prompt_keys.lua` and see all four scenarios pass

## 14. Preserve direct 99 prompt mappings
Scenarios: `ai: Shift-Enter opens vibe prompt`, `ai: Visual Alt-9 opens visual prompt`, `ai: Visual Shift-Enter opens visual prompt`
- [ ] 14.1 Update the preserved mapping cases in `tests/integration/ai/test_prompt_keys.lua` and run `make test FILE=tests/integration/ai/test_prompt_keys.lua`, seeing the changed expectations fail before the entry-keymap rewrite
- [ ] 14.2 Keep the normal Shift-Enter and visual Alt-9 and Shift-Enter paths while separating their callbacks for action reuse
- [ ] 14.3 Run `make test FILE=tests/integration/ai/test_prompt_keys.lua` and see all three scenarios pass

## 15. Keep 99 mapping scope and silence
Scenarios: `ai: Entry mappings are silent`, `ai: Select mode keeps its default behavior`
- [ ] 15.1 Update the cases in `tests/unit/ai/test_entry_keymaps.lua` and run `make test FILE=tests/unit/ai/test_entry_keymaps.lua`, seeing both changed scenarios fail
- [ ] 15.2 Register only the specified silent normal and visual mappings and leave select mode untouched
- [ ] 15.3 Run `make test FILE=tests/unit/ai/test_entry_keymaps.lua` and see both scenarios pass
