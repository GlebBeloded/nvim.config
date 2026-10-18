## Why

Kind: bug

`diff: Reindented blocks respect the move deadline` fails on auto 3 of 3 runs: comparing 2000 `}` lines with 2000
`  }` lines with `moves = true` takes 1474–1763 ms and neither finishes within 150 ms nor times out cleanly by
1200 ms (× load factor). The 1000 ms deadline is overrun by 500–750 ms, so some loop on this path (the line diff
under the default policy, the move passes, or the inner comparisons) checks the deadline too rarely or not at all.
Every gate in the loop is red on it, whatever change runs.

## Evidence

- `make test FILE=tests/unit/diff/test_moves_perf.lua` on auto 50a8b0a: `1473.7 ms`, `1750.3 ms`, `1763.1 ms neither
  completed within budget nor timed out cleanly` (tests/unit/diff/test_moves_perf.lua:86)
- the engine files are unchanged since dad95f8 (`fix(diff): skip moves on too-big fallback`)

## What Changes

- Find the loop that runs past the deadline with a headless probe that times each phase on this input, and check
  the shared deadline inside it (per iteration or per bounded batch), so the comparison stops within ~50 ms of the
  deadline and reports `timed_out` with `moves = {}`; the test's bounds and input stay unchanged.

## Impact

- lua/gleb/diff/engine/ (the overrunning loop)
- tests/unit/diff/test_moves_perf.lua (unchanged; must pass)
