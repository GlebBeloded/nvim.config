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

## What Changes

- Time each move pass on this input (simple pass, window pass, `lines_similar`, joins, the per-move inner
  comparison) with the probe, find every loop that runs without a deadline check, and check the shared deadline
  inside each (per iteration or per bounded batch), so moves stop within ~50 ms after the deadline with
  `timed_out = true` and `moves = {}`. The test's bounds and input stay unchanged.

## Impact

- lua/gleb/diff/engine/moves.lua (and init.lua if the per-move inner comparison ignores the deadline)
