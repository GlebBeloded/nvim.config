## ADDED Requirements

### Requirement: Move detection
With `opts.moves`, `compare_lines` SHALL fill `result.moves` with blocks moved between the sides, as VS Code's `computeMovedLines` finds them in the line fragments. Each move SHALL hold `start1`, `end1`, `start2`, `end2` (0-based, half-open) and `fragments`, the comparison of the moved text under the call's policy and highlight mode, in absolute line numbers. Without `opts.moves`, `moves` SHALL be empty. `fragments` SHALL stay unchanged.

#### Scenario: A moved block is detected
- **WHEN** `compare_lines(a, b, { moves = true })` is called with `a = { "local limit = 2048", "local cheap = true", "local count = 10", "function a() end", "function b() end", "function c() end", "function d() end" }` and `b` the same lines with the three `local` lines moved to the end
- **THEN** `fragments` is `{ { 0, 3, 0, 0 }, { 7, 7, 4, 7 } }` as `{ start1, end1, start2, end2 }`, and `moves` is one move `{ start1 = 0, end1 = 3, start2 = 4, end2 = 7 }` whose `fragments` are empty

#### Scenario: A moved block with an edit carries its inner diff
- **WHEN** the same comparison is made but the moved copy reads `local limit = 1024`
- **THEN** `moves` is one move `{ start1 = 0, end1 = 3, start2 = 4, end2 = 7 }`. Its `fragments` are one fragment `{ start1 = 0, end1 = 1, start2 = 4, end2 = 5 }` with `inner` `{ { start1 = 14, end1 = 18, start2 = 14, end2 = 18 } }`

#### Scenario: A block moved next to an edit is found by line windows
- **WHEN** `a` from the first move scenario gets a last line `return M`, and `b` is the four `function` lines, then the three `local` lines, then `return X`, compared with `moves = true`
- **THEN** `fragments` is `{ { 0, 3, 0, 0 }, { 7, 8, 4, 8 } }` as `{ start1, end1, start2, end2 }`, and `moves` is one move `{ start1 = 0, end1 = 3, start2 = 4, end2 = 7 }`

#### Scenario: Moves are off by default
- **WHEN** the first move scenario's lines are compared without `moves`
- **THEN** `moves` is empty and `fragments` equal those of the first move scenario

#### Scenario: A too big fallback skips move detection
- **WHEN** a comparison exceeds its Myers threshold and falls back to xdiff with `moves = true`
- **THEN** `too_big` is true and `moves` is empty

### Requirement: Move thresholds
Moves SHALL keep VS Code's thresholds:
- at least 3 lines;
- a deletion and insertion pair only above 0.90 histogram similarity;
- 3-line windows of trimmed lines in other changes;
- growth into touching lines that are trim-equal or share over 60% of the longer line's non-space characters, with more than 10 of them;
- moves joined when their gaps sum to at most 2 lines;
- under 15 trimmed characters dropped, as are moves within one change.

#### Scenario: Short moves are ignored
- **WHEN** `{ "x=10", "y=20", "z=30" }` followed by the four `function` lines is compared with `moves = true` against the four `function` lines followed by `{ "x=10", "y=20", "z=30" }`
- **THEN** `fragments` is `{ { 0, 3, 0, 0 }, { 7, 7, 4, 7 } }` as `{ start1, end1, start2, end2 }`, and `moves` is empty, because the moved text has 14 characters

#### Scenario: Two-line moves are ignored
- **WHEN** `{ "local limit = 2048", "local cheap = true" }` followed by the four `function` lines is compared with `moves = true` against the four `function` lines followed by the two `local` lines
- **THEN** `moves` is empty

### Requirement: Bounded move detection
Move detection and the inner diffs of moves SHALL share the call's deadline and inner limits. When the deadline passes during move detection, `moves` SHALL be empty and `timed_out` set, while `fragments` stay.

#### Scenario: A deadline during move detection drops moves
- **WHEN** the first move scenario's lines are compared with `moves = true` and a clock that returns 0 until `require("gleb.diff.engine.moves").compute` is entered and 5000 after it
- **THEN** `moves` is empty, `timed_out` is true and `fragments` is `{ { 0, 3, 0, 0 }, { 7, 7, 4, 7 } }` as `{ start1, end1, start2, end2 }`

#### Scenario: Reindented blocks respect the move deadline
- **WHEN** 2000 lines containing `}` are compared with 2000 lines containing `  }` using `moves = true`
- **THEN** the call takes under 150 ms times the load factor, or returns near the shared deadline with empty `moves`, `timed_out` true and `too_big` false

#### Scenario: Move detection on a 5000-line file stays within budget
- **WHEN** the design's 5000-line input and its copy with 40 lines moved to the end are compared with `moves = true`, once to warm up and then 3 times
- **THEN** the median call takes under 150 ms times the load factor, and `moves` holds exactly one move of 40 lines on each side whose `fragments` are empty

### Requirement: VS Code move goldens
`moves.lua`, given VS Code's own line changes, SHALL reproduce the expected moves of all 58 fixture folders of VS Code's `src/vs/editor/test/node/diffing/fixtures/`, translated into Lua tables under `tests/unit/diff/fixtures/vscode_moves/`. `NOTICE` SHALL credit Visual Studio Code (© Microsoft Corporation) with the MIT License text.

#### Scenario: Every VS Code move fixture passes
- **WHEN** `moves.compute` runs on each of the 58 tables with its `changes`, `lines1` and `lines2`
- **THEN** each result equals the table's `moves`: `{ { 23, 27, 69, 73 } }` for `move-1`, `{ { 222, 225, 157, 160 } }` for `difficult-move`, `{ { 476, 536, 106, 164 } }` for `noisy-move1`, and none for the other 55, `false-positive-move` included

#### Scenario: NOTICE credits VS Code
- **WHEN** `lua/gleb/diff/engine/NOTICE` and `moves.lua` are read
- **THEN** `NOTICE` contains `Visual Studio Code`, `Microsoft Corporation` and `Permission is hereby granted, free of charge`, and the first comment of `moves.lua` names `computeMovedLines.ts` and the MIT license

## MODIFIED Requirements

### Requirement: Engine attribution
`lua/gleb/diff/engine/` SHALL hold a `NOTICE` that credits IntelliJ IDEA (© JetBrains s.r.o.) and diffbandit.nvim (© Corey Kaylor) under the Apache License 2.0, plus that license's text. Every ported Lua file and every fixture table translated from upstream tests SHALL start with a header naming its upstream file, project and license, and saying it was modified. `moves.lua` and `fixtures/vscode_moves/*` SHALL name the MIT license; the other ported files SHALL name Apache-2.0.

#### Scenario: Ported files carry their attribution
- **WHEN** `NOTICE`, every `.lua` file under `lua/gleb/diff/engine/` and every file recursively under `tests/unit/diff/fixtures/` are read
- **THEN** `NOTICE` names `IntelliJ IDEA`, `JetBrains s.r.o.`, `diffbandit.nvim`, `Corey Kaylor` and `Apache License`, `LICENSE-APACHE-2.0` exists, and each Lua file's first comment names its upstream path, modification and applicable Apache-2.0 or MIT license
