## 1. Bound repeated move candidates by the shared deadline
Scenarios: `diff: Reindented blocks respect the move deadline`
- [x] 1.1 Run `make test FILE=tests/unit/diff/test_moves_perf.lua CASE="Reindented blocks respect the move deadline"` and confirm the existing failure reported in the proposal (`1473.7 ms`, `1750.3 ms`, or `1763.1 ms neither completed within budget nor timed out cleanly`)
- [x] 1.2 Check the shared deadline inside the original-window candidate loop in `lua/gleb/diff/engine/moves.lua` and abort move detection with no moves when it expires
- [x] 1.3 Run `make test FILE=tests/unit/diff/test_moves_perf.lua CASE="Reindented blocks respect the move deadline"` and see it pass
