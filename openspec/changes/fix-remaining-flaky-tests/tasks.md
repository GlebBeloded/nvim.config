## 1. Make plugin-surface ownership probes load-safe
Scenarios: `loop: Known flaky cases use deterministic readiness`, `actions: Plugin-window mappings are action-owned`
- [x] 1.1 Treat the proposal's 6 rerun passes and 300 s hang as the failing evidence; update `tests/integration/actions/test_plugin_ownership.lua` to preserve the mapping audit and blocked-descendant assertions while exposing which readiness or cleanup state missed its deadline
- [x] 1.2 Scale unavoidable `tests/helpers.lua` surface-open and teardown deadlines with `H.load_factor()`, and make blocked child/descendant cleanup completion observable without weakening the 10-second product contract
- [x] 1.3 Run `make test FILE=tests/integration/actions/test_plugin_ownership.lua CASE="Plugin-window mappings are action-owned"` and see it pass

## 2. Wait for reference positions and highlights to settle
Scenarios: `loop: Known flaky cases use deterministic readiness`, `references: Preview highlighting matches a regular buffer`, `references: UTF-16 usage columns are converted to byte columns`
- [x] 2.1 Treat the proposal's 6 and 3 rerun passes as the failing evidence; tighten `tests/integration/references/test_preview.lua` and `tests/integration/references/test_keys.lua` to assert explicit parser-capture and post-edit LSP readiness while preserving every capture and byte-column assertion
- [x] 2.2 Add the smallest test synchronization helper or read-only references hook needed to observe Treesitter parse completion and gopls acknowledgement of the rewritten source
- [x] 2.3 Run `make test FILE=tests/integration/references/test_preview.lua CASE="Preview highlighting matches a regular buffer"` and `make test FILE=tests/integration/references/test_keys.lua CASE="UTF-16 usage columns are converted to byte columns"` and see both pass

## 3. Drive first-paint status completion deterministically
Scenarios: `loop: Known flaky cases use deterministic readiness`, `file-tree: First paint waits for ignored status`
- [x] 3.1 Treat the proposal's 6 rerun passes as the failing evidence; tighten `tests/integration/file-tree/test_ignored.lua` so the existing first-frame omission assertion fails if paint precedes a controlled pending status result, without racing a scheduled callback against 300 ms
- [x] 3.2 Add the smallest file-tree test hook needed to release the real first-status callback and observe the first draw after that event; keep the 300 ms product fallback unchanged
- [x] 3.3 Run `make test FILE=tests/integration/file-tree/test_ignored.lua CASE="First paint waits for ignored status"` and see it pass

## 4. Observe project-tree burst quiescence
Scenarios: `loop: Known flaky cases use deterministic readiness`, `file-tree: Project tree runs git status once per burst`
- [x] 4.1 Treat the proposal's 4 rerun passes as the failing evidence; tighten `tests/integration/file-tree/test_project_git.lua` to retain the 20-row and at-most-2-runs assertions while reporting the debounce/watch state that has not settled
- [x] 4.2 Replace the bare 1000 ms completion window with a load-scaled event/state wait for all rows and quiescent git work, using an existing counter or the smallest read-only hook
- [x] 4.3 Run `make test FILE=tests/integration/file-tree/test_project_git.lua CASE="Project tree runs git status once per burst"` and see it pass

## 5. Capture the diff screen only after rendering settles
Scenarios: `loop: Known flaky cases use deterministic readiness`, `diff: Diff view matches the approved render`
- [x] 5.1 Treat the proposal's 4 rerun passes as the failing evidence; tighten `tests/screen/diff/test_view.lua` so the unchanged approved text and colour mask are checked only after the real diff view's asynchronous render state is observable
- [x] 5.2 Make `tests/render/cases.lua` wait on the real populated layout, redraw, and highlight readiness rather than only a non-nil view object
- [x] 5.3 Run `make test FILE=tests/screen/diff/test_view.lua CASE="Diff view matches the approved render"` and see it pass

## 6. Wait for the final Diffview layout
Scenarios: `loop: Known flaky cases use deterministic readiness`, `git: Diffview file panel on the left`
- [x] 6.1 Treat the proposal's 3 rerun passes as the failing evidence; tighten `tests/integration/git/test_git.lua` to preserve the leftmost `DiffviewFiles` and width-35 assertions while diagnosing incomplete layout readiness
- [x] 6.2 Scale the unavoidable Diffview timeout with `H.load_factor()` and wait for the final leftmost panel tuple, not merely separate window existence
- [x] 6.3 Run `make test FILE=tests/integration/git/test_git.lua CASE="Diffview file panel on the left"` and see it pass

## 7. Observe the pending tree refresh after toggle
Scenarios: `loop: Known flaky cases use deterministic readiness`, `keymaps: Toggle wins over a pending tree refresh`
- [ ] 7.1 Treat the proposal's 3 rerun passes as the failing evidence; tighten `tests/integration/keymaps/test_keymaps.lua` to retain the absent-tree and editor-focus assertions while making a controlled real refresh pending before `<A-e>`
- [ ] 7.2 Replace the fixed 1000 ms sleep with a test-driven refresh completion event or state and then assert the closed panel was not recreated
- [ ] 7.3 Run `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="Toggle wins over a pending tree refresh"` and see it pass

## Agent decisions

- All eight intents are deterministically testable, so no case or scenario is deleted and every assertion remains in force.
- The proposal contains rerun counts but no literal gate `FAIL in` lines; tasks use those supplied counts as the closest available red evidence and do not search historical run artifacts or manufacture load.
- The stale proposal label “Toggle wins over pending filesystem render” maps to the existing `keymaps: Toggle wins over a pending tree refresh` scenario located by symbol.
- Surface timeout errors report the readiness expression and `child`/`descendants` cleanup states so a loaded-host miss identifies both the wait and teardown outcome.
- Treesitter readiness means a capture exists at the reference position, while rewritten Go readiness requires two real gopls reference responses from that buffer.
- The file-tree initial-status hook pauses the initial-draw boundary and suppresses its fallback only while the test controls completion, leaving the production 300 ms deadline unchanged.
- Project-tree burst readiness uses existing view, Git-root, and watcher state so the run-count assertion is sampled only after every debounce and refresh is quiescent.
- Diff render readiness requires the fixture's complete 24-row layout and Treesitter captures in both real diff buffers before a forced redraw.
- Diffview readiness is the final `{leftmost filetype, width, target diff window}` tuple, sampled with a load-scaled deadline so intermediate split layouts cannot satisfy it.
