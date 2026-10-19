## Why

Kind: bug

Two VS Code parity gaps in move detection that reviews noted but never fixed (archon runs 0519a45b `reviews.md` and
`escalation.md`, 0f98b5ef `reviews.md`):

1. `remove_moves_in_same_change` (`lua/gleb/diff/engine/moves.lua:566`) treats a missing change on both sides
   (`nil == nil`) as the same change and drops the move; VS Code and the diff-engine-moves Decision treat it as a
   different change. Current inputs may not reach it: probe whether any input does.
2. `lines_similar` (`moves.lua:286`) returns false when `lcs.diff` reports `too_big`; VS Code's Myers never gives up for
   size, so long similar lines are wrongly treated as dissimilar.

## What Changes

- Treat `nil` vs `nil` as different changes, as VS Code does; add a scenario reaching it if an input can, else a unit
  case on the function.
- Make `lines_similar` decide long lines the way VS Code does (no size give-up, within the existing move deadline);
  add a scenario with a long moved line that VS Code reports as moved.
- Keep every existing diff scenario and its bounds (the moves deadline stays).

## Evidence

- `lua/gleb/diff/engine/moves.lua:585` retains a move only when its two containing-change ids differ, so
  `nil == nil` drops a move that belongs to neither change. Candidates produced by `moves.compute` cannot reach that
  state: simple candidates come from non-empty deletion and insertion changes at
  `lua/gleb/diff/engine/moves.lua:120` and `lua/gleb/diff/engine/moves.lua:127`, while line-window candidates are
  constructed inside change ranges at `lua/gleb/diff/engine/moves.lua:389` and
  `lua/gleb/diff/engine/moves.lua:409`. The parity branch therefore needs a direct unit case.
- `lua/gleb/diff/engine/moves.lua:295` rejects two lines over 300 characters before measuring similarity, and
  `lua/gleb/diff/engine/moves.lua:319` also treats every non-`ok` LCS result as dissimilar; the bounded LCS can exhaust
  Myers and patience at `lua/gleb/diff/engine/lcs.lua:573` and `lua/gleb/diff/engine/lcs.lua:577`.
- A headless `make probe` using a three-line moved anchor followed by 350-character lines made from 220 shared
  characters and 130 differing characters returned `{ { 0, 3, 4, 7 } }`; VS Code parity requires the similar fourth
  line to extend that move to `{ { 0, 4, 4, 8 } }`.

## Impact

- `lua/gleb/diff/engine/moves.lua`, `lua/gleb/diff/engine/lcs.lua`, and `tests/unit/diff/test_moves.lua`.
- No plugin dependency is added, removed, or upgraded; core keymaps do not change.
- Out of scope: diff-view rendering, line-diff fallback policy, move thresholds other than size give-up, and the existing
  move deadline and performance bounds.

## Decision (auditor, 2026-10-19, review pass 1)

- Gap 2 in this proposal overstated VS Code: upstream `areLinesSimilar` (`computeMovedLines.ts`) still returns false
  when both lines are longer than 300 characters, before Myers. Keep the `MAX_SIMILAR_LINE = 300` guard exactly as
  VS Code has it. The change is only that `lines_similar` does not give up (`too_big`) for lines within that limit,
  where VS Code's Myers always decides; if `lcs.diff` cannot report `too_big` for lines of at most 300 characters, gap 2
  needs no code change and its scenario asserts the VS Code result for a long (≤ 300 chars) moved line.
