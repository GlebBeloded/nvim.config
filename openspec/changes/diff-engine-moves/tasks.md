## 1. VS Code fixtures

Scenarios: `diff: Every VS Code move fixture passes`

- [ ] 1.1 Fetch the pinned VS Code sparse clone into a temp dir outside the repo (design.md, Context). Write `drafts/vscode_moves.py`, which turns each of the 58 `advanced.expected.diff.json` files into `tests/unit/diff/fixtures/vscode_moves/<folder>.lua` (design Decision 5, with the header).
- [ ] 1.2 Write `tests/unit/diff/test_moves_goldens.lua`, asserting 58 tables and naming the failing folder, and see it fail

## 2. Port computeMovedLines

Scenarios: `diff: Every VS Code move fixture passes`, `diff: Short moves are ignored`, `diff: Two-line moves are ignored`

- [ ] 2.1 Write the two threshold scenarios in `tests/unit/diff/test_moves.lua` and see them fail
- [ ] 2.2 Add `lua/gleb/diff/engine/moves.lua`:
  - Port `computeMovedLines.ts` and `LineRangeFragment` function by function, with the constants of design Decision 2 and the `countNonWsChars` quirk.
  - Use `lcs.lua` for `lines_similar`.
- [ ] 2.3 Make `test_moves_goldens.lua` and the two scenarios pass. If a golden fails only on a borderline `lines_similar` decision, port VS Code's Myers tie-breaking for that function (design, Risks). Never drop or edit a golden.

## 3. Engine integration

Scenarios: `diff: A moved block is detected`, `diff: A moved block with an edit carries its inner diff`, `diff: A block moved next to an edit is found by line windows`, `diff: Moves are off by default`, `diff: A deadline during move detection drops moves`, `diff: Move detection on a 5000-line file stays within budget`

- [ ] 3.1 Write the scenarios in `tests/unit/diff/test_moves.lua` and `test_moves_perf.lua`, and see them fail. The deadline case wraps `moves.compute` to flip its fake clock.
- [ ] 3.2 Add the `moves` option, `result.moves`, the shifted inner diff per move and the shared deadline to `init.lua` (design Decisions 3 and 4)
- [ ] 3.3 Make both files pass

## 4. Attribution and check

Scenarios: `diff: NOTICE credits VS Code`

- [ ] 4.1 Write the scenario in `tests/unit/diff/test_notice.lua` and see it fail
- [ ] 4.2 Add the VS Code line and MIT text to `NOTICE`, and the header to `moves.lua` and every fixture table. `diff: Ported files carry their attribution` must still pass.
- [ ] 4.3 Run `make check`
