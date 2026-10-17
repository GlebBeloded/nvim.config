## Why

Kind: feature
Depends: diff-engine-words

When a block of code moves, a line diff shows it as an unrelated deletion and insertion. Reviewing a refactor then means matching the two halves by eye. The user asked for move detection, but only if IntelliJ doesn't have it. IntelliJ has none: YouTrack IJPL-101150 has been open since 2015, and nothing in `platform/util/diff` detects moves. VS Code does, in its diff editor, with `computeMovedLines` (329 lines, MIT), so the user picked a port of that.

This change adds the port to the engine and returns moves next to the IntelliJ line fragments. `diff-view-actions` draws them.

## What Changes

- **New `lua/gleb/diff/engine/moves.lua`.** It ports VS Code's `computeMovedLines.ts` and `LineRangeFragment` (`utils.ts`), keeping VS Code's thresholds exactly:
  - **Simple moves.** A pure deletion of 3 or more lines pairs with the pure insertion of 3 or more lines whose character histogram is most similar. The pair is a move when the similarity is above 0.90. Each insertion is used at most once.
  - **Moves in changed blocks.** Among the remaining changes, 3-line windows of whitespace-trimmed lines are matched between the two sides and extended while consecutive windows keep matching.
    - Mappings are taken longest first, and only the parts not already claimed that are 3 or more lines long are kept.
    - Each move then grows up and down into its touching changes while the lines are similar. Similar means trimmed-equal, or, for lines up to 300 characters, more than 60% of the longer line's non-space characters in common, where that line has more than 10 of them.
  - **Joining and filtering.**
    - Consecutive moves whose two gaps (each non-negative) sum to 2 lines or fewer are joined.
    - A move is dropped when its original text, trimmed and joined, has fewer than 15 characters, or when fewer than 2 of its lines have 2 or more characters.
    - A move is dropped when both its ends fall in the same change.
- **API:**
  - `compare_lines(lines1, lines2, { moves = true })` fills `result.moves`. Each move has the moved line ranges on both sides and `fragments`, the IntelliJ comparison of the moved text with the call's policy and highlight mode, in absolute line numbers.
  - `moves` defaults to false, as in VS Code's API. The fragments themselves are unchanged: moves annotate the deletions and insertions, they don't replace them.
- **Bounded:**
  - Move detection shares the call's deadline. When the deadline passes, `moves` is empty and `timed_out` is set, as VS Code returns no moves on timeout.
  - A move's inner diff obeys the inner limits of `diff-engine-words`, since it goes through the same pipeline.
- **Fixtures.** All 58 folders of VS Code's `src/vs/editor/test/node/diffing/fixtures/` become Lua tables under `tests/unit/diff/fixtures/vscode_moves/`. Each table holds the texts, VS Code's line changes and its expected moves:
  - 3 fixtures expect a move: `move-1`, `difficult-move`, `noisy-move1`.
  - 55 expect none, including `false-positive-move`.
  - The tables run against `moves.lua` with VS Code's own changes, so the port is checked independently of the IntelliJ line diff.
- **Attribution.** `NOTICE` adds "Visual Studio Code, Copyright (c) Microsoft Corporation, MIT License" with the full MIT text. `moves.lua` and the fixture tables carry headers naming their VS Code paths.

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `diff`: adds the requirements for move detection, move filtering, the moved-block inner diff, the move deadline and the VS Code move goldens.

## Impact

- Code: new `lua/gleb/diff/engine/moves.lua`. Changed: `init.lua` (the `moves` option, `result.moves`, the moved-block inner diff) and `NOTICE`.
- Tests: unit tests in a bare child (`tests/unit/diff/`):
  - `test_moves.lua`
  - `test_moves_goldens.lua`
  - `test_moves_perf.lua`
  - 58 fixture tables, about 270 KB of VS Code test text.
- Plugins: none. Alternatives considered:
  - IntelliJ: no move detection (IJPL-101150).
  - vscode-diff.nvim already in the config computes VS Code's diff and moves in C. But it would bring a second line diff and its own UI, while the user picked "own the UI" and IntelliJ's line diff.
  - Neovim's xdiff: no moves.
- Core keymaps: none.
- Unchanged scenarios: none pinned, since no existing module changes. The `diff` scenarios of `diff-engine-lines` and `diff-engine-words` still hold, because `moves` is off unless asked for, and `fragments` never change.
- Out of scope:
  - Drawing moves, jumping between a move's ends and the `DiffViewMoved` group (`diff-view-actions`).
  - Moves across files.
  - Copy detection: a block that stays and is also inserted elsewhere is not a move in VS Code either.
  - Merge and conflict views.

## Decision (user, 2026-10-17)

- Move detection: "Let's get Move detection (but only if IDEA doesn't have it)". IntelliJ has none (YouTrack IJPL-101150, open since 2015), so the user picked "Port VS Code's move detection".
- "I'm used to Idea", "I like IDEA IDE diff more". The move ranges sit on top of IntelliJ's line fragments.

## Agent decisions

- **Input changes.** Moves are computed from IntelliJ's line fragments, not VS Code's, so they always match what the viewer shows. The goldens feed VS Code's own changes to `moves.lua`, so they test the port exactly.
- **Inner diff of a move.**
  - VS Code refines a move with its own char diff. Here the moved text runs through `compare_lines` with the call's policy and highlight mode, so a moved block's highlights look like any other change.
  - Its fragments use absolute line numbers, so the viewer needs no offset maths.
- **Characters.**
  - VS Code counts UTF-16 units in histograms and lengths. The port counts UTF-8 code points, which is identical for BMP text.
  - Trimming follows JavaScript's `trim` for ASCII whitespace.
  - Similar lines count their common characters with the engine's own LCS on code points. Where several optimal LCS exist, the count of common non-space characters may differ from VS Code's Myers by a few characters.
- **VS Code quirk kept.** `countNonWsChars` in `areLinesSimilar` loops over the first line's length even when it measures the second line. It is ported as is, with a comment, so the goldens match VS Code.
