## 1. Bound move candidate processing by the shared deadline
Scenarios: `diff: Reindented blocks respect the move deadline`
- [ ] 1.1 Use the proposal's existing failing gate evidence (1844–1904 ms, 3 of 3) for `tests/unit/diff/test_moves_perf.lua` as the required failing run; keep its 2000-line input and timing bounds unchanged
- [ ] 1.2 Time the move passes with that input, replace the uninterruptible full candidate ordering in `lua/gleb/diff/engine/moves.lua` with deadline-bounded work, and add shared-deadline checks to any remaining move loops that can overrun; update `lua/gleb/diff/engine/init.lua` only if per-move inner comparison fails to honor the same deadline
- [ ] 1.3 Run `make test FILE=tests/unit/diff/test_moves_perf.lua CASE="Reindented blocks respect the move deadline"` and see it pass

## Stuck

- Task 1 exhausted two implementation attempts; the second attempt is saved in `stuck-attempt.diff` in the run artifacts.
- Probe: the unchanged engine took 13.5 ms without moves and 1842.2 ms with moves; the instrumented first attempt made 7,996,009 clock calls, spending its first ~600 ms in the window-candidate scan and the remainder in candidate processing.
- Attempt 1 replaced the full candidate sort with deadline-checked length buckets and checked the other move loops. The scenario still failed at 958.4 ms because processing completed just before the deadline without qualifying for the 150 ms fast path or reporting a timeout.
- Attempt 2 grouped windows by change and skipped same-change seeds that are normally discarded later. The deadline scenario and focused move tests passed, but `diff: Every VS Code move fixture passes` regressed at `bracket-aligning`, where `{ { 79, 84, 92, 97 } }` was lost. Production edits were reverted; the existing deadline regression remains red for the fix pass.
