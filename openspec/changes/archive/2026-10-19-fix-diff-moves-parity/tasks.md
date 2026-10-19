## 1. Retain moves outside every change
Scenarios: `diff: Moves with no containing change are retained`
- [x] 1.1 Write the test `diff: Moves with no containing change are retained` in `tests/unit/diff/test_moves.lua`, calling `remove_moves_in_same_change` through its `moves.compute` upvalue with the specified populated changes and move, and see it fail
- [x] 1.2 Make `remove_moves_in_same_change` retain a move when either containing-change id is missing while continuing to drop moves whose two non-nil ids match
- [x] 1.3 Run `make test FILE=tests/unit/diff/test_moves.lua CASE="Moves with no containing change are retained"` and see it pass

## 2. Extend moves through long similar lines
Scenarios: `diff: Long similar lines extend a move`
- [x] 2.1 Write the test `diff: Long similar lines extend a move` in `tests/unit/diff/test_moves.lua`, driving `moves.compute` with the specified changes, anchor lines, stable lines, and 350-character lines, and see it fail with `{ { 0, 3, 4, 7 } }`
- [x] 2.2 Give `lines_similar` a deadline-aware exact LCS path that does not reject long lines or return `too_big`, while preserving the shared move deadline
- [x] 2.3 Run `make test FILE=tests/unit/diff/test_moves.lua CASE="Long similar lines extend a move"` and see it pass
- [x] 2.4 Run `make test FILE=tests/unit/diff/test_moves.lua`, `make test FILE=tests/unit/diff/test_moves_goldens.lua`, and `make test FILE=tests/unit/diff/test_moves_perf.lua` and confirm every existing move scenario and deadline bound still passes

## Agent decisions

- Expose the existing Myers implementation as `lcs.diff_exact` with a full edit-distance bound, reusing its shared deadline instead of adding a second LCS algorithm.
