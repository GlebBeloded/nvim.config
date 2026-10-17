## Context

See proposal.md (Why). Research, 2026-10-17:

- **IntelliJ.** It has no move detection. `platform/util/diff` holds no move code, and the feature request YouTrack IJPL-101150 has been open since 2015.
- **VS Code.** `computeMovedLines` (`src/vs/editor/common/diff/defaultLinesDiffComputer/computeMovedLines.ts`, 329 lines, MIT) runs after the line diff when `computeMoves` is set.
  - `defaultLinesDiffComputer.ts` hashes every line as `l.trim()` through one perfect-hash map. The same hashes drive the 3-line windows.
  - It refines each move with `refineDiff` into `MovedText(mapping, changes)`.
  - `LineRangeFragment.computeSimilarity` (`utils.ts`) builds a histogram per line range: each UTF-16 unit, plus one `\n` per line. Its similarity is `1 - Σ|h1 - h2| / (total1 + total2)`.
  - `isSpace` is only space or tab.
- **Source pin.**

  | Source | Pin | Fetch |
  |---|---|---|
  | VS Code, MIT | `5b23ab39bef800e5c4dad4e544671ef20617e660` (2026-10-17); `computeMovedLines.ts` last changed in `014c000f` | `git clone --filter=blob:none --sparse https://github.com/microsoft/vscode`, then `git sparse-checkout set src/vs/editor/common/diff/defaultLinesDiffComputer src/vs/editor/test/node/diffing` |

  As in `diff-engine-lines`, the clone is data in a temp dir outside the repo, never built or run.
- **VS Code's goldens.** `src/vs/editor/test/node/diffing/fixtures.test.ts` runs every fixture folder (`1.tst`, `2.tst`, `advanced.expected.diff.json`) with `computeMoves: true`, an unlimited timeout and `ignoreTrimWhitespace` only for folders named `*trimws*`.
  - Of the 58 folders, three expect moves. Their `[a,b)` ranges are 1-based, end-exclusive:

    | Folder | Original | Modified |
    |---|---|---|
    | `move-1` | `[24,28)` | `[70,74)`: the `const enum Constants` block moved down, `2048` → `1024` |
    | `difficult-move` | `[223,226)` | `[158,161)` |
    | `noisy-move1` | `[477,537)` | `[107,165)` |

  - `false-positive-move` expects none.
- **diffbandit.nvim.** No move code, so nothing to seed. `moves.lua` is a fresh port.

## Goals / Non-Goals

**Goals:**
- VS Code's move ranges, threshold for threshold, checked against VS Code's own fixtures.
- Moves that fit the IntelliJ fragments the viewer shows, with an inner diff in the engine's own format.

**Non-Goals:**
- Drawing or navigating moves (`diff-view-actions`).
- Cross-file moves, copies.

## Decisions

1. **Module.**
   - `moves.lua` exposes `M.compute(changes, lines1, lines2, ctx)`, where `changes` are `{ start1, end1, start2, end2 }` ranges, 0-based half-open and ordered.
   - It returns the move ranges in the same shape, sorted by `start1`.
   - It mirrors VS Code's functions one to one, with 1-based line numbers rewritten 0-based:
     - `moves_from_simple_changes`
     - `unchanged_moves`
     - `lines_similar`
     - `join_close_moves`
     - `remove_moves_in_same_change`
   - Line hashes are integer ids from a table keyed by the trimmed line. Trimming strips ASCII whitespace (`" \t\n\r\v\f"`), as JavaScript's `trim` does for ASCII.
2. **Thresholds** are `UPPER_SNAKE` constants at the top of `moves.lua` (rule 4.3), with VS Code's values:

   | Constant | Value | VS Code expression |
   |---|---|---|
   | `MIN_MOVE_LINES` | 3 | `original.length >= 3`, `modified.length >= 3`, `s.length < 3` skip, 3-line hash windows |
   | `MIN_SIMILARITY` | 0.90 | `highestSimilarity > 0.90` (strict) |
   | `SIMILAR_RATIO` | 0.6 | `commonNonSpaceCharCount / longerLineLength > 0.6` |
   | `SIMILAR_MIN_CHARS` | 10 | `longerLineLength > 10` |
   | `MAX_SIMILAR_LINE` | 300 | both lines `> 300` chars → not similar |
   | `JOIN_MAX_GAP` | 2 | `originalDist + modifiedDist <= 2`, both `>= 0` |
   | `MIN_MOVE_CHARS` | 15 | trimmed original lines joined with `\n`, length `>= 15` |
   | `MIN_LINE_CHARS`, `MIN_LONG_LINES` | 2, 2 | at least 2 trimmed lines of length `>= 2` |

   - Lengths and histograms count UTF-8 code points.
   - The `countNonWsChars` quirk (it iterates over `line1.length` for either line) is kept, with a comment citing VS Code.
3. **Pipeline in `init.lua`.** With `opts.moves`:
   1. Take the final IntelliJ fragments, after squash or split.
   2. Pass their line ranges to `moves.compute`.
   3. For each move, run `compare_lines(slice1, slice2)` with the same `policy`, `highlight` and the shared deadline context, then shift its fragments by `start1`/`start2`.
   - Without `opts.moves`, `result.moves` is `{}`.

   ```lua
   ---@class gleb.diff.Move
   ---@field start1 integer  moved block on side 1 (0-based, half-open)
   ---@field end1 integer
   ---@field start2 integer  where it landed on side 2
   ---@field end2 integer
   ---@field fragments gleb.diff.LineFragment[]  differences inside the moved text, absolute line numbers; {} when moved unchanged

   ---@class gleb.diff.Options
   ---@field moves? boolean  default false

   ---@class gleb.diff.Result
   ---@field moves gleb.diff.Move[]  sorted by start1
   ```

   `fragments` is never changed by move detection, so a move's lines stay covered by their deletion and insertion fragments. `diff-view-actions` decides how to tint them.
4. **Deadline.** `moves.compute` checks the shared context after each deletion in the simple pass and after each change in the window pass, as VS Code checks its timeout. On expiry, `result.moves = {}` and `timed_out = true`. The line fragments and their inner ranges stay.
5. **Fixtures.** `drafts/vscode_moves.py` reads each `advanced.expected.diff.json` of the pinned clone and writes `tests/unit/diff/fixtures/vscode_moves/<folder>.lua`:

   ```lua
   -- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
   -- src/vs/editor/test/node/diffing/fixtures/move-1/advanced.expected.diff.json
   -- Modified: JSON rewritten as Lua data, ranges made 0-based.
   return {
     lines1 = { ... },          -- original.content split on "\n"
     lines2 = { ... },
     trim_ws = false,           -- folder name contains "trimws"
     changes = { { 23, 27, 23, 23 }, { 73, 73, 69, 73 } },  -- VS Code "diffs", 0-based
     moves = { { 23, 27, 69, 73 } },
   }
   ```

   - The golden test runs `moves.compute(changes, lines1, lines2)` with an unlimited deadline and expects `moves` exactly.
   - The move's inner `changes` in the JSON are not compared: they are VS Code's char diff, not the engine's.
6. **Performance bound.**
   - The `diff-engine-lines` generator (Decision 5), with the 40 lines that came from `lines1` lines 2101–2140 (1-based, none of them edited) moved to the end of `lines2`.
   - `compare_lines(lines1, lines2, { moves = true })` takes under 150 ms × `H.load_factor()`, as the median of 3 runs after a warm-up.
   - It returns exactly one move, 40 lines on each side, whose `fragments` are empty.
7. **Attribution.** `NOTICE` gains the line "Portions derived from Visual Studio Code, Copyright (c) Microsoft Corporation, licensed under the MIT License:" and the full MIT permission text. `moves.lua` header:

   ```lua
   -- Lua port of microsoft/vscode src/vs/editor/common/diff/defaultLinesDiffComputer/computeMovedLines.ts
   -- and LineRangeFragment in utils.ts (MIT, © Microsoft Corporation). Modified: rewritten in Lua,
   -- 0-based ranges, code-point counts; see NOTICE.
   ```

## Risks / Trade-offs

- **The IntelliJ line diff differs from VS Code's.** A move VS Code finds can be missed here, or found with other bounds, when the two line diffs split a region differently. That is accepted: moves must fit the fragments the viewer shows. The goldens pin the port itself.
- **Fixture size.** About 270 KB of text. It lives only in `tests/unit/diff/fixtures/vscode_moves/` and is read only by its own test.
- **LCS choice in `lines_similar`.** Only the borderline 60% decisions can differ from VS Code's. If a golden fails on one, the fix is to port VS Code's `MyersDiffAlgorithm` tie-breaking for this one function, not to drop the golden.

## Renders

None. This change has no visible UI: it extends a pure library. Moved-block tint (`DiffViewMoved`) and its renders come with `diff-view-actions`.
