# diff Specification

## Purpose
Compares two texts the way IntelliJ IDEA's diff does (a Lua port of its comparison engine: lines, words and chars under its whitespace policies, plus VS Code's move detection) and shows the result in a two-pane viewer with IntelliJ chrome.

## Requirements

### Requirement: Line comparison API
`require("gleb.diff.engine").compare_lines(lines1, lines2, opts)` SHALL return a result whose `fragments` list the changed line ranges in order, as 0-based half-open `start1`, `end1`, `start2`, `end2`. Fragments SHALL be disjoint, never empty on both sides, and separated by equal lines. Identical inputs SHALL give no fragments. The engine SHALL load without any plugin.

#### Scenario: Changed lines become fragments
- **WHEN** `compare_lines({ "x", "y", "z" }, { "n", "k", "y" })` is called
- **THEN** `fragments` is `{ { start1 = 0, end1 = 1, start2 = 0, end2 = 2 }, { start1 = 2, end1 = 3, start2 = 3, end2 = 3 } }`, and `too_big` and `timed_out` are false

#### Scenario: Identical lines have no fragments
- **WHEN** `compare_lines({ "a", "b" }, { "a", "b" })` is called
- **THEN** `fragments` is empty

#### Scenario: Lines added after an empty line
- **WHEN** `compare_lines({ "" }, { "", "", "" })` is called
- **THEN** `fragments` is `{ { start1 = 1, end1 = 1, start2 = 1, end2 = 3 } }`

#### Scenario: The engine loads without plugins
- **WHEN** a bare child (no user config, no plugins) requires `gleb.diff.engine` and compares two line arrays
- **THEN** the call succeeds and every newly loaded module is under `gleb.diff.engine`

### Requirement: IntelliJ line matching
The line comparison SHALL follow IntelliJ's ByLine. Lines with at most 3 non-space characters SHALL NOT anchor the first matching pass. A whitespace-insensitive first pass SHALL be corrected so exactly equal lines pair up. Ambiguous insertions and deletions SHALL slide to empty-line boundaries. Myers SHALL run on lines unique-discarded by the Reindexer.

#### Scenario: Brace lines do not anchor a match
- **WHEN** `compare_lines({ "{", "}" }, { "{", " {", " }", "}", "x" })` is called
- **THEN** `fragments` is `{ { start1 = 1, end1 = 1, start2 = 1, end2 = 3 }, { start1 = 2, end1 = 2, start2 = 4, end2 = 5 } }`

#### Scenario: Shifted indentation realigns exactly
- **WHEN** `compare_lines({ ".{", "..{", "...{" }, { "..{", "...{" })` is called
- **THEN** `fragments` is `{ { start1 = 0, end1 = 1, start2 = 0, end2 = 0 } }`

#### Scenario: An inserted function slides to the empty line
- **WHEN** `compare_lines` gets `{ "fun a() {", "    body", "}", "", "fun c() {", "    body", "}" }` and the same lines with `"fun b() {", "    body", "}", ""` inserted after the first empty line
- **THEN** `fragments` is `{ { start1 = 4, end1 = 4, start2 = 4, end2 = 8 } }`

### Requirement: Whitespace policies
`opts.policy` SHALL be one of four values. `default` compares lines exactly. `trim_whitespaces` ignores leading and trailing whitespace. `ignore_whitespaces` ignores all whitespace. `ignore_whitespaces_chunks` compares like `ignore_whitespaces`, then drops each fragment at either end of a run of adjoining fragments whose two sides are equal once whitespace is removed. Whitespace SHALL be space, tab and newline.

#### Scenario: Trim and ignore policies differ on inner spaces
- **WHEN** `{ "x y", "x y", "x y" }` and `{ "  x y  ", "x y  ", "x   y" }` are compared under `default`, `trim_whitespaces` and `ignore_whitespaces`
- **THEN** the fragments are `{ { 0, 3, 0, 3 } }`, `{ { 2, 3, 2, 3 } }` and none, written as `{ start1, end1, start2, end2 }`

#### Scenario: Trailing whitespace line under trim
- **WHEN** `{ "x", "" }` and `{ "x " }` are compared under `default` and under `trim_whitespaces`
- **THEN** the fragments are `{ { 0, 2, 0, 1 } }` and `{ { 1, 2, 1, 1 } }`

#### Scenario: Empty lines count unless chunks are ignored
- **WHEN** `{ "", "", "z", "", "" }` and `{ "z" }` are compared under `ignore_whitespaces` and under `ignore_whitespaces_chunks`
- **THEN** the first gives `{ { 0, 2, 0, 0 }, { 3, 5, 1, 1 } }` and the second gives no fragments

#### Scenario: Carriage return is not whitespace
- **WHEN** `{ "a\r" }` and `{ "a" }` are compared under `ignore_whitespaces`
- **THEN** `fragments` is `{ { start1 = 0, end1 = 1, start2 = 0, end2 = 1 } }`

### Requirement: Bounded comparison
Myers SHALL give up past IntelliJ's edit threshold, `max(20000 + 10·⌊√(n1+n2)⌋, 20000)` or `opts.limits.myers_threshold`, and Patience with unique-line anchors SHALL take over. When Patience cannot halve the problem, or the call passes `opts.limits.timeout_ms` (default 1000) on `opts.limits.clock`, the result SHALL be the xdiff histogram line ranges, with `too_big` or `timed_out` set.

#### Scenario: Patience takes over when Myers exceeds its threshold
- **WHEN** `compare_lines({ "alpha", "bravo", "charlie", "delta", "echo" }, { "echo", "bravo", "charlie", "delta", "alpha" }, { limits = { myers_threshold = 1 } })` is called
- **THEN** `fragments` is `{ { 0, 1, 0, 1 }, { 4, 5, 4, 5 } }` as `{ start1, end1, start2, end2 }`, and `too_big` is false

#### Scenario: A too big comparison falls back to xdiff
- **WHEN** `compare_lines({ "alpha", "bravo", "alpha", "bravo" }, { "bravo", "bravo", "alpha", "alpha" }, { limits = { myers_threshold = 1 } })` is called
- **THEN** `too_big` is true and `fragments` is `{ { 0, 1, 0, 1 }, { 3, 4, 3, 4 } }`, the histogram ranges of `vim.text.diff` made 0-based

#### Scenario: A missed deadline falls back to xdiff
- **WHEN** `compare_lines({ "alpha", "bravo" }, { "alpha", "charlie" }, { limits = { timeout_ms = 1000, clock = c } })` is called, where `c` returns 0 on its first call and 5000 afterwards
- **THEN** `timed_out` is true, `too_big` is false and `fragments` is `{ { start1 = 1, end1 = 2, start2 = 1, end2 = 2 } }`

#### Scenario: A 5000-line file compares within budget
- **WHEN** the design's generated 5000-line input and its edited copy (50 edits, 10 insertions, 10 deletions) are compared with default options, once to warm up and then 3 times
- **THEN** the median call takes under 100 ms times the load factor, and `fragments` has 70 entries

#### Scenario: A 100000-line suffix edit meets deadline
- **WHEN** a 100000-line file and a copy with only its last line changed are compared with the default 1 s deadline
- **THEN** the call takes under 1 s, returns one fragment, and `too_big` and `timed_out` are false

#### Scenario: Patience reduction uses original counts
- **WHEN** Myers hands Patience a problem whose large anchored gap trims below half of the original counts
- **THEN** Patience continues with linear Myers instead of falling back, and `too_big` and `timed_out` are false

### Requirement: IntelliJ line goldens
The engine SHALL reproduce IntelliJ's own line test expectations and diffbandit's IntelliJ-oracle goldens. They are translated into Lua tables under `tests/unit/diff/fixtures/`: `LineComparisonUtilTest` (69 cases), `ComparisonUtilTest` (33 trim-equality and 12 line-fragment cases) and diffbandit's 5 oracle cases. The engine SHALL also keep IntelliJ's line invariants on fixed-seed random texts.

#### Scenario: Every IntelliJ line case passes
- **WHEN** each row of `intellij_lines.lua` is compared under each policy it lists
- **THEN** the fragments equal the row's change list, or the changed line indices equal its matching sets, for all 69 rows

#### Scenario: IntelliJ trim equality and line fragments hold
- **WHEN** each row of `intellij_equality.lua` is checked
- **THEN** the trim-equality verdict and the line ranges match all 45 rows

#### Scenario: diffbandit oracle goldens pass
- **WHEN** each of the 5 rows of `diffbandit_oracle.lua` is compared with the `default` policy
- **THEN** the fragments equal the row's expected ranges

#### Scenario: Random texts keep IntelliJ's line invariants
- **WHEN** 30 seeded random text pairs per alphabet (with and without emoji) are compared under all four policies
- **THEN** every result has ordered, disjoint, in-range fragments, its gaps are equal under the policy, and its ignore-policy fragments cannot be trimmed

### Requirement: Engine attribution
`lua/gleb/diff/engine/` SHALL hold a `NOTICE` that credits IntelliJ IDEA (© JetBrains s.r.o.) and diffbandit.nvim (© Corey Kaylor) under the Apache License 2.0, plus that license's text. Every ported Lua file and every fixture table translated from upstream tests SHALL start with a header naming its upstream file, project and license, and saying it was modified. `moves.lua` and `fixtures/vscode_moves/*` SHALL name the MIT license; the other ported files SHALL name Apache-2.0.

#### Scenario: Ported files carry their attribution
- **WHEN** `NOTICE`, every `.lua` file under `lua/gleb/diff/engine/` and every file recursively under `tests/unit/diff/fixtures/` are read
- **THEN** `NOTICE` names `IntelliJ IDEA`, `JetBrains s.r.o.`, `diffbandit.nvim`, `Corey Kaylor` and `Apache License`, `LICENSE-APACHE-2.0` exists, and each Lua file's first comment names its upstream path, modification and applicable Apache-2.0 or MIT license

### Requirement: Inner fragments
Each `compare_lines` fragment SHALL carry `inner`: 0-based half-open changed-byte ranges (`start1`, `end1`, `start2`, `end2`) relative to each side's comparison text. That text is the fragment's lines joined with `"\n"`, plus the final `"\n"` when another line follows on that side; a range MAY cover it. `inner` SHALL be nil for a whole-fragment change (pure insertion, deletion or `by_line`) and `{}` when the sides are equal under the policy. No range SHALL split a UTF-8 character.

#### Scenario: Changed words inside a line
- **WHEN** `compare_lines({ "x z " }, { "y z" })` is called with the `default` policy, then with `trim_whitespaces`
- **THEN** both give one fragment `{ 0, 1, 0, 1 }` as `{ start1, end1, start2, end2 }`. Its inner ranges cover exactly left bytes 0 and 3 and right byte 0 under `default`, and left byte 0 and right byte 0 under `trim_whitespaces`

#### Scenario: A deleted word leaves an insertion point
- **WHEN** `compare_lines({ "x? y" }, { "x y" })` is called
- **THEN** the one fragment's `inner` is `{ { start1 = 1, end1 = 2, start2 = 1, end2 = 1 } }`

#### Scenario: A pure insertion has no inner list
- **WHEN** `compare_lines({ "z" }, { "z", "w" })` is called
- **THEN** `fragments` is one fragment `{ start1 = 1, end1 = 1, start2 = 1, end2 = 2 }` whose `inner` is nil

#### Scenario: A whitespace-only insertion has an empty inner list
- **WHEN** `{ "z" }` and `{ "z", " " }` are compared under `ignore_whitespaces` and under `ignore_whitespaces_chunks`
- **THEN** the first gives one fragment `{ start1 = 1, end1 = 1, start2 = 1, end2 = 2 }` with `inner` equal to `{}`, and the second gives no fragments

### Requirement: Highlight modes
`opts.highlight` SHALL be one of five modes:
- `by_word` (default): word inner ranges, with adjoining fragments squashed into one;
- `by_word_split`: word inner ranges, a changed block split into the line groups that belong together;
- `by_char`: character inner ranges, squashed;
- `by_line`: no inner ranges;
- `none`: no fragments.

#### Scenario: Split mode keeps unrelated lines apart
- **WHEN** `{ "x", "y" }` and `{ "a", "b y" }` are compared with `by_word_split`, then with `by_word`
- **THEN** `by_word_split` gives `{ { 0, 1, 0, 1 }, { 1, 2, 1, 2 } }` and `by_word` gives `{ { 0, 2, 0, 2 } }`, written as `{ start1, end1, start2, end2 }`

#### Scenario: Char mode marks single characters
- **WHEN** `compare_lines({ "x y z" }, { "x  z" }, { highlight = "by_char" })` is called
- **THEN** the one fragment `{ 0, 1, 0, 1 }` has `inner` equal to `{ { start1 = 2, end1 = 3, start2 = 2, end2 = 2 } }`

#### Scenario: Line mode and no highlighting
- **WHEN** `{ "x z " }` and `{ "y z" }` are compared with `by_line`, then with `none`
- **THEN** `by_line` gives one fragment `{ 0, 1, 0, 1 }` with `inner` nil, and `none` gives no fragments

### Requirement: Whole-text word and char comparison
`compare_words(text1, text2, opts)` and `compare_chars(text1, text2, opts)` SHALL return the changed byte ranges of two texts under `opts.policy`, without squashing. Words SHALL follow IntelliJ's tokens: runs of letters, digits and `_`, split by space, tab, newline and ASCII punctuation. Each continuous-script code point (CJK, kana, Thai, emoji, non-letter symbols) SHALL be a word of its own.

#### Scenario: CJK characters are words of their own
- **WHEN** `compare_words("汉语漢語", "語汉语漢")` is called
- **THEN** the returned ranges cover exactly left bytes 9, 10 and 11 and right bytes 0, 1 and 2

#### Scenario: An emoji change spans its whole character
- **WHEN** `compare_chars("x😂y", "x🤫y")` is called
- **THEN** it returns `{ { start1 = 1, end1 = 5, start2 = 1, end2 = 5 } }`

#### Scenario: Punctuation separates words
- **WHEN** `compare_words("x,y", "x")` is called
- **THEN** the returned ranges cover exactly left bytes 1 and 2 and no right byte

### Requirement: Inner comparison limits
A fragment's inner comparison SHALL fail when a side exceeds `opts.limits.max_inner_bytes` (default 50000) or its LCS is too big. The fragment then keeps `inner` nil. After 3 failures, no later fragment SHALL be compared. When the call deadline passes during the inner phase, the remaining fragments SHALL keep `inner` nil and `timed_out` SHALL be set, while the line fragments stay.

#### Scenario: Inner comparison stops after three failures
- **WHEN** `{ "aaaaaaa1", "same one", "aaaaaaa2", "same two", "aaaaaaa3", "same three", "x y" }` and the same lines with `bbbbbbb1`, `bbbbbbb2`, `bbbbbbb3` and `x z` are compared with `limits = { max_inner_bytes = 4 }`
- **THEN** there are 4 fragments, and all 4 have `inner` nil

#### Scenario: Small fragments keep inner ranges after two failures
- **WHEN** `{ "aaaaaaa1", "same one", "aaaaaaa2", "same two", "x y" }` and `{ "bbbbbbb1", "same one", "bbbbbbb2", "same two", "x z" }` are compared with `limits = { max_inner_bytes = 4 }`
- **THEN** the first two fragments have `inner` nil and the third, `{ start1 = 4, end1 = 5, start2 = 4, end2 = 5 }`, has `inner` equal to `{ { start1 = 2, end1 = 3, start2 = 2, end2 = 3 } }`

#### Scenario: A deadline during inner comparison keeps the line diff
- **WHEN** `{ "alpha one", "keep a", "bravo two", "keep b", "charlie three" }` and `{ "alpha 1", "keep a", "bravo 2", "keep b", "charlie 3" }` are compared with a clock that returns 0 until the first word comparison of a fragment starts and 5000 after it
- **THEN** `timed_out` is true, the fragments are `{ 0, 1, 0, 1 }`, `{ 2, 3, 2, 3 }` and `{ 4, 5, 4, 5 }` as `{ start1, end1, start2, end2 }`, and the last one has `inner` nil

#### Scenario: Inner ranges for 500 changed lines stay within budget
- **WHEN** the design's 5000-line input and its copy with 500 one-word edits are compared with `by_word`, once to warm up and then 3 times
- **THEN** the median call takes under 200 ms times the load factor, and each of the 500 fragments has one inner range

### Requirement: Inner highlight columns
`inner_columns(fragment, side, lines)` SHALL map a fragment's inner ranges on one side to `{ row, col_start, col_end }` entries. Rows are 0-based buffer rows and columns are byte columns. A range that spans a newline SHALL become one entry per row, without the newline byte. An insertion point SHALL be a zero-width entry. When `inner` is nil, it SHALL return nil.

#### Scenario: Squashed word ranges map to buffer columns
- **WHEN** `compare_lines({ "keep", "a b", "c d" }, { "keep", "a x", "c y" })` is called and `inner_columns` is asked for each side of its fragment
- **THEN** the fragment is `{ start1 = 1, end1 = 3, start2 = 1, end2 = 3 }` with `inner` `{ { 2, 3, 2, 3 }, { 6, 7, 6, 7 } }` as `{ start1, end1, start2, end2 }`, and both sides map to `{ { row = 1, col_start = 2, col_end = 3 }, { row = 2, col_start = 2, col_end = 3 } }`

#### Scenario: A range across a newline splits per row
- **WHEN** `inner_columns` gets the fragment `{ start1 = 0, end1 = 2, start2 = 0, end2 = 1, inner = { { start1 = 2, end1 = 5, start2 = 0, end2 = 0 } } }`, once for side 1 with `{ "a b", "c d" }` and once for side 2 with `{ "x" }`
- **THEN** side 1 maps to `{ { row = 0, col_start = 2, col_end = 3 }, { row = 1, col_start = 0, col_end = 1 } }` and side 2 to `{ { row = 0, col_start = 0, col_end = 0 } }`

### Requirement: IntelliJ word and char goldens
The engine SHALL reproduce IntelliJ's word, char, split and character-class test expectations, translated into Lua tables under `tests/unit/diff/fixtures/` with byte offsets:
- `WordComparisonUtilTest`: 78 cases;
- `CharComparisonUtilTest`: 71 cases;
- `SplitComparisonUtilTest` and `LineComparisonUtilTest` splitters: 27 cases;
- `TrimUtilTest`.

It SHALL also keep IntelliJ's inner invariants on fixed-seed random texts.

#### Scenario: Every IntelliJ word case passes
- **WHEN** each of the 78 rows of `intellij_words.lua` is checked under each policy it lists
- **THEN** `compare_words`, and for `lines_inner` rows the single squashed `by_word` fragment, give the row's ranges or changed-byte sets

#### Scenario: Every IntelliJ char case passes
- **WHEN** each of the 71 rows of `intellij_chars.lua` is checked under each policy it lists
- **THEN** `compare_chars`, or the raw char LCS for `chars_raw` rows, gives the row's ranges or changed-byte sets

#### Scenario: Every IntelliJ split case passes
- **WHEN** each of the 27 rows of `intellij_split.lua` is compared with its row's highlight mode and policy
- **THEN** the fragments' line ranges equal the row's expectation

#### Scenario: IntelliJ character classes hold
- **WHEN** every code point from U+0000 to U+FFFF is classified, along with the alpha and continuous-script strings of `intellij_chars_classes.lua`
- **THEN** exactly the 31 characters ``(){}[],./?`~!@#$%^&*-=+|\;:'"<>`` are punctuation, and every string's alpha and continuous-script verdicts match the table

#### Scenario: Random texts keep IntelliJ's inner invariants
- **WHEN** 30 seeded random text pairs per alphabet (with and without emoji) are compared with `compare_words`, `compare_chars` and `compare_lines` in `by_word`, `by_word_split` and `by_char`, under all four policies
- **THEN** every range is ordered and in bounds and splits no UTF-8 character; gaps are equal byte-for-byte under `default` and without whitespace under every other policy; changed chunks differ byte-for-byte under `default` and `trim_whitespaces` and without whitespace under the ignore-whitespace policies; and inner ranges stay inside their fragment's comparison text, including its trailing newline when another line follows

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
