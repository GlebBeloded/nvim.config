## Why

Kind: bug

The first fix (10f540d, "bound move candidate scan by deadline") is not enough: move detection still runs about
1 s past its 1000 ms deadline on reindented blocks, so `diff: Reindented blocks respect the move deadline` still
fails on auto (1844–1904 ms, 3 of 3).

## Evidence

Headless probe on auto 492e6f1 (2000 `}` lines vs 2000 `  }` lines):

```
nvim --headless --clean --cmd "set rtp^=." -c 'lua local l1,l2={}, {} for i=1,2000 do l1[i]="}" l2[i]="  }" end
  local e=require("gleb.diff.engine") for _,m in ipairs({false,true}) do local t=vim.uv.hrtime()
  local r=e.compare_lines(l1,l2,{moves=m}) io.write(("moves=%s %.0f ms timed_out=%s\n"):format(tostring(m),
  (vim.uv.hrtime()-t)/1e6,tostring(r.timed_out))) end' -c qa
moves=false 35 ms timed_out=false
moves=true 1981 ms timed_out=true
```

The line diff takes 35 ms; the move passes spend ~1950 ms and only report the timeout at the end.

A clock probe on the same input first observes the expired deadline at 1876.8 ms from
`lua/gleb/diff/engine/moves.lua:357`. The preceding `table.sort(possible, ...)` at
`lua/gleb/diff/engine/moves.lua:348` has no deadline check and sorts the full candidate set before control reaches
that check. This uninterruptible candidate ordering is the demonstrated overrun; the other unchecked move loops
must also be bounded so they cannot become the next overrun after it is fixed.

## What Changes

- Time each move pass on this input (simple pass, window pass, `lines_similar`, joins, the per-move inner
  comparison) with the probe, find every loop that runs without a deadline check, and check the shared deadline
  inside each (per iteration or per bounded batch), so moves stop within ~50 ms after the deadline with
  `timed_out = true` and `moves = {}`. The test's bounds and input stay unchanged.

## Impact

- lua/gleb/diff/engine/moves.lua (and init.lua if the per-move inner comparison ignores the deadline)
- `diff: Changed lines become fragments` still holds because a move timeout preserves the completed line fragments.
- `diff: A missed deadline falls back to xdiff` still holds because line-comparison fallback is unchanged.
- `diff: A 100000-line suffix edit meets deadline` still holds because the base comparison path is unchanged.
- `diff: Patience reduction uses original counts` still holds because move detection runs after Patience finishes.
- `diff: A deadline during inner comparison keeps the line diff` still holds because inner-comparison timeout handling is unchanged.
- `diff: A deadline during move detection drops moves` still holds and guards the required empty-move timeout result.
- `diff: Reindented blocks respect the move deadline` still holds and is the existing failing regression scenario this fix must satisfy.
- `diff: Requirement: Diff view editing` still holds because propagated move timeouts continue to retain fragments and mark the view approximate.
