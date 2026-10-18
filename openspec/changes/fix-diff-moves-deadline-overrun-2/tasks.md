## 1. Bound move candidate processing by the shared deadline
Scenarios: `diff: Reindented blocks respect the move deadline`
- [x] 1.1 Use the proposal's existing failing gate evidence (1844–1904 ms, 3 of 3) for `tests/unit/diff/test_moves_perf.lua` as the required failing run; keep its 2000-line input and timing bounds unchanged
- [x] 1.2 Time the move passes with that input, replace the uninterruptible full candidate ordering in `lua/gleb/diff/engine/moves.lua` with deadline-bounded work, and add shared-deadline checks to any remaining move loops that can overrun; update `lua/gleb/diff/engine/init.lua` only if per-move inner comparison fails to honor the same deadline
- [x] 1.3 Run `make test FILE=tests/unit/diff/test_moves_perf.lua CASE="Reindented blocks respect the move deadline"` and see it pass

## Agent decisions

- Poll the shared deadline every 256 candidate operations, bounding overrun while avoiding millions of clock calls.
