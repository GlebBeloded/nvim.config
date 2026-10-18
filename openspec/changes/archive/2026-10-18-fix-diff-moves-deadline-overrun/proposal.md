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
- `diff: Changed lines become fragments` still holds because the deadline check only aborts move detection after the line diff is complete.
- `diff: A missed deadline falls back to xdiff` still holds because the line-diff deadline fallback is unchanged.
- `diff: A 100000-line suffix edit meets deadline` still holds because the line-diff fast path and its deadline checks are unchanged.
- `diff: Patience reduction uses original counts` still holds because patience reduction and its counting inputs are unchanged.
- `diff: A deadline during inner comparison keeps the line diff` still holds because inner comparison remains separate from move detection and keeps the completed line diff.
- `diff: A deadline during move detection drops moves` still holds because the added check exits move detection and the engine discards moves after the shared deadline.
- `diff: Reindented blocks respect the move deadline` still holds and directly guards the repeated-window candidate scan fixed by this change.
- `diff: Requirement: Diff view editing` still holds because the change does not alter diff-view buffers, mappings, or editing behavior.
