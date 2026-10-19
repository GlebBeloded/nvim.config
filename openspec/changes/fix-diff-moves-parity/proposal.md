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

## Impact

- `lua/gleb/diff/engine/moves.lua`, `tests/unit/diff/` move cases.

## Decision (auditor, 2026-10-19, review pass 1)

- Gap 2 in this proposal overstated VS Code: upstream `areLinesSimilar` (`computeMovedLines.ts`) still returns false
  when both lines are longer than 300 characters, before Myers. Keep the `MAX_SIMILAR_LINE = 300` guard exactly as
  VS Code has it. The change is only that `lines_similar` does not give up (`too_big`) for lines within that limit,
  where VS Code's Myers always decides; if `lcs.diff` cannot report `too_big` for lines of at most 300 characters, gap 2
  needs no code change and its scenario asserts the VS Code result for a long (≤ 300 chars) moved line.
