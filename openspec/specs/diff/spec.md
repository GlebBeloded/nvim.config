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

#### Scenario: Moves with no containing change are retained
- **WHEN** the same-change filter is called with changes `{ { 5, 8, 5, 8 } }` and move `{ 0, 3, 0, 3 }`
- **THEN** the move is retained because neither side belongs to a change

#### Scenario: Long similar lines extend a move
- **WHEN** `moves.compute` receives changes `{ { 0, 4, 0, 0 }, { 8, 8, 4, 8 } }`, with three equal anchor lines followed by 220 `a` and 80 `b` characters on the original side, four stable lines, then the same anchors followed by 220 `a` and 130 `c` characters on the modified side
- **THEN** it returns `{ { 0, 4, 4, 8 } }`, extending the move through the 300- and 350-character lines without exceeding the shared deadline

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

### Requirement: Diff view opens the current file
`diff.open_file` SHALL compare the current file at `HEAD` (left) with the current buffer's lines (right) in a new tab page. The left window SHALL hold a read-only scratch buffer with filetype `gleb-diff`. The right window SHALL show the file's own buffer, with the cursor on the first change. A file without changes SHALL notify `No changes` (INFO). A buffer outside a git work tree SHALL notify `Not in a git repository` (WARN). In both cases nothing opens.

#### Scenario: Diff view opens on the current file
- **WHEN** `internal/user/controller.go` of a fresh copy of the `diffgo` fixture is the current buffer and `diff.open_file` runs
- **THEN** there are 2 tab pages and the current one has exactly two windows:
  - the left buffer has filetype `gleb-diff` and holds the lines of `git show HEAD:internal/user/controller.go`;
  - the right window shows the buffer that was current, unchanged;
  - the cursor is in the right window on line 53.

#### Scenario: Diff view of an unchanged file opens nothing
- **WHEN** `git checkout -- internal/user/controller.go` has run in a copy of the `diffgo` fixture, the file is edited and `diff.open_file` runs
- **THEN** `No changes` is notified at INFO and there is still 1 tab page

#### Scenario: Diff view outside a repository opens nothing
- **WHEN** a file in a temporary directory outside any git work tree is the current buffer and `diff.open_file` runs
- **THEN** `Not in a git repository` is notified at WARN and there is still 1 tab page

#### Scenario: Diff view of a file absent from HEAD
- **WHEN** `internal/user/new.go` is created with the lines `package user`, ``, `var x = 1` in a copy of the `diffgo` fixture, edited, and `diff.open_file` runs
- **THEN** the left buffer is empty and `require("gleb.diff.view").current().fragments` is `{ { start1 = 0, end1 = 0, start2 = 0, end2 = 3 } }`

#### Scenario: Diff view focuses an open view of the same file
- **WHEN** the view of `internal/user/controller.go` is open, `gt` returns to the first tab page and `diff.open_file` runs again there
- **THEN** there are still 2 tab pages and the second, holding the view, is current

### Requirement: Diff view layout
The view SHALL split its area into a left window 40% of the width (rounded down) and a right window. The right window's `statuscolumn` SHALL be a 16-cell gutter: the apply arrow `»` and the include checkbox `☐` on the first row of each change, the left and right line numbers, and a 5-cell change strip. A side with no lines for a change SHALL show `╱` padding rows, so rows stay aligned. Changed rows SHALL be tinted by kind. The winbars SHALL read `<short hash> · HEAD` and `Your version`.

#### Scenario: Diff view matches the approved render
- **WHEN** a `100x30` screen edits `internal/user/controller.go` of a fresh copy of the `diffgo` fixture and `diff.open_file` runs
- **THEN** screen rows 2–29 match design.md "Proposed D — aligned diff of the current file", text and colour mask

#### Scenario: Diff view pads the side without lines
- **WHEN** the view of `internal/user/controller.go` (`diffgo` fixture) is open
- **THEN** the left window shows exactly one `╱` row, between old lines 57 and 58. The right window shows exactly one, between new lines 65 and 66. With every fold open, both windows span the same number of screen rows.

#### Scenario: Diff view gutter shows both line numbers
- **WHEN** the view of `internal/user/controller.go` (`diffgo` fixture) is open
- **THEN** the right window's status column:
  - reads `  52       52   ` on new line 52, the unchanged row;
  - reads `» 53       53 ☐ ` on new line 53, the changed row (with Nerd Font glyphs for `☐`);
  - starts with `»╱╱╱╱` on new line 58, the inserted row.

### Requirement: Diff view folds
Each unchanged run SHALL keep up to 4 lines next to each neighbouring change. When at least 2 more lines remain, they SHALL fold into one closed fold in each window. On the left, the fold row reads `~~ <n> unchanged lines ~~~` to the window's edge; on the right, it is `~` to the edge. `diff.expand_fold` SHALL open the fold under the cursor in both windows. `diff.toggle_folds` SHALL open every fold when any is closed, and otherwise close them all.

#### Scenario: Diff view folds unchanged lines with context 4
- **WHEN** the view of `internal/user/controller.go` (`diffgo` fixture) is open
- **THEN** each window has exactly two closed folds:
  - lines 1–48, shown as `~~ 48 unchanged lines ~~…` on the left;
  - lines 70–151 of both sides, shown as `~~ 82 unchanged lines ~~…`.

  Lines 49–69 of the left and right buffers are not folded.

#### Scenario: Diff view zo opens a fold in both windows
- **WHEN** the cursor is on line 1 of the right window of the `controller.go` view and `zo` is pressed in normal mode
- **THEN** `foldclosed(1)` is `-1` in both windows, and lines 70–151 are still folded in both

#### Scenario: Diff view zR toggles every fold
- **WHEN** `zR` is pressed in normal mode in the right window of the `controller.go` view, and then pressed again
- **THEN** after the first press neither window has a closed fold, and after the second press both have their two folds closed again

### Requirement: Diff view word highlights
Inside a changed fragment, the view SHALL highlight each side's inner ranges with `DiffViewWord`, as `compare_lines` gives them with the `by_word` mode and mapped with `inner_columns`. A zero-width range and a pure insertion or deletion SHALL get no word highlight.

#### Scenario: Diff view highlights changed words
- **WHEN** the view of `internal/user/controller.go` (`diffgo` fixture) is open
- **THEN** the right buffer's line 53 (`\t\treturn wrap(err)`) has `DiffViewWord` exactly on byte columns 9–13 and 17. The left buffer's line 53 and right line 58 have none.

### Requirement: Diff view synchronized scrolling
Scrolling either window SHALL scroll the other so that the same aligned row is at the top, and keep the same `leftcol`. Moving the cursor in one window SHALL put the other window's cursor on the transferred line. That line is the same offset past the start of the enclosing unchanged run or change, clamped to the change's end (IntelliJ `BaseSyncScrollable.transferLine`).

#### Scenario: Diff view scrolls both windows together
- **WHEN** every fold of the `controller.go` view is open and `62zt` is typed in normal mode in the right window
- **THEN** the right window's topline is 62 and the left window's topline is 61

#### Scenario: Diff view maps the cursor across changes
- **WHEN** the right cursor of the `controller.go` view moves to line 58, then to line 59, and then the left cursor moves to line 65
- **THEN** the left cursor is on line 58 after each of the first two moves, and the right cursor is then on line 66

#### Scenario: Layout maps cursor rows across changes
- **WHEN** the layout for the three `controller.go` changes transfers right lines 58 and 59 and left line 65
- **THEN** they map to left lines 58 and 58 and right line 66, and left line 58 belongs to change 2

### Requirement: Diff view change navigation
`diff.next_change` and `diff.prev_change` SHALL move the cursor in the current window to the first line of the next or previous change on that window's side. For a side without lines, that is the line just below the gap. There is no wrap: at the last or first change, the cursor stays.

#### Scenario: Diff view ]c and [c walk the changes
- **WHEN** the view of `controller.go` opens (right cursor on line 53) and `]c` is pressed three times, then `[c` once, in normal mode
- **THEN** the right cursor goes to lines 58, 66 and 66, then 58

#### Scenario: Diff view ]c on the left side
- **WHEN** the left cursor of the `controller.go` view is on line 53 and `]c` is pressed twice in normal mode
- **THEN** the left cursor goes to line 58 and then to line 65

### Requirement: Diff view editing
The left buffer SHALL NOT be modifiable. Each change to the right buffer SHALL re-compare after a 150 ms debounce and redraw tints, padding, folds and gutter. The cursor and the folds opened by the user SHALL stay. When the engine falls back (`too_big` or `timed_out`), the right winbar SHALL read `Your version · approximate diff`.

#### Scenario: Diff view left window is read-only
- **WHEN** `x` is pressed in normal mode on line 53 of the left window of the `controller.go` view
- **THEN** the left buffer's lines are unchanged and its `modifiable` option is off

#### Scenario: Diff view re-diffs after an edit
- **WHEN** `dd` is pressed in normal mode on right line 58 of the `controller.go` view, 300 ms pass, `u` is pressed and 300 ms pass
- **THEN**
  - after `dd`, the view has two fragments (old 53 changed, old 65 deleted) and the left window has no padding row;
  - after `u`, it has the three original fragments again.

#### Scenario: Diff view marks an approximate comparison
- **WHEN** `require("gleb.diff.view").config.timeout_ms` is `0` and `diff.open_file` runs on `controller.go` of the `diffgo` fixture
- **THEN** the right window's winbar reads `Your version · approximate diff`

### Requirement: Diff view closing
`diff.close` in either window SHALL close the view and return to the window that was current before it opened. A view opened by `diff.open_file` closes its tab page. Closing either window by other means SHALL close the other window too. On close, the view SHALL remove its buffer-local mappings, extmarks and autocmds from the file buffer and restore any buffer-local mapping it shadowed.

#### Scenario: Diff view q closes the tab page
- **WHEN** `q` is pressed in normal mode in the right window of the `controller.go` view
- **THEN**
  - there is 1 tab page and the current window shows `controller.go`;
  - that buffer has no buffer-local `]c` mapping and no extmark in the view's namespace.

#### Scenario: Diff view closes with either window
- **WHEN** `:quit` is run in the left window of the `controller.go` view
- **THEN** there is 1 tab page and no window shows a `gleb-diff` buffer

#### Scenario: Diff view restores a shadowed buffer mapping
- **WHEN** `controller.go` has a buffer-local normal-mode `q` mapping, and its view is opened and then closed with `q`
- **THEN** the buffer's `q` mapping is the one it had before the view opened

#### Scenario: Diff view keys stay native outside view windows
- **WHEN** the `controller.go` view is open, lines 1–10 are manually folded in its original window, which also had a buffer-local `]c` mapping, and `zo` then `]c` are pressed there
- **THEN** the manual fold opens and the buffer-local `]c` mapping runs

### Requirement: Diff view embedding
`require("gleb.diff.view").show(win, spec)` SHALL show a view in the area of window `win`, without changing the current window or the tab page count. `spec` holds `path`, `left` (lines), `right` (a buffer or lines), `labels` and an optional `on_next_file`. The cursor SHALL start on the first change's first line (right) and its transferred line (left). A later `show` on the same area SHALL replace the view. `diff.next_file` SHALL call `on_next_file`; without one, it does nothing.

#### Scenario: Diff view shows in a given window without focus
- **WHEN** a second window is open, and from the first one `show(<second>, { path = "b.txt", left = { "a", "b" }, right = { "a", "c" }, labels = { "HEAD", "Working tree" } })` runs
- **THEN**
  - the tab page count is unchanged and the first window is still current;
  - the second window's area holds two windows, with lines `a`, `b` on the left and `a`, `c` on the right;
  - the left winbar reads ` HEAD`.

#### Scenario: Diff view show starts on the first change
- **WHEN** a second window is open, and from the first one `show(<second>, { path = "d.txt", left = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l" }, right = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "J", "k", "l" }, labels = { "HEAD", "Working tree" } })` runs
- **THEN** the first window is still current, the right window's cursor is on line 10 and the left window's cursor is on line 10

#### Scenario: Diff view ]f calls the next-file hook
- **WHEN** a view shown with an `on_next_file` callback has its right window focused and `]f` is pressed in normal mode
- **THEN** the callback ran once

#### Scenario: Diff view ]f without a list keeps the view
- **WHEN** `]f` is pressed in normal mode in the right window of the `controller.go` view opened by `diff.open_file`
- **THEN** the view, its buffers and the cursor are unchanged

### Requirement: Diff view keys
The view SHALL set its mappings buffer-local (`nowait`) in both windows. They come from the registered `diff.*` actions whose `plugin` is `gleb-diff`, with their `settings/keymap.json` assignments at open time. `diff.open_file` SHALL be a registered action without an assignment.

#### Scenario: Diff view mappings come from diff actions
- **WHEN** the `controller.go` view is open after `VeryLazy`
- **THEN** every buffer-local mapping of both windows invokes the `diff.*` action that `settings/keymap.json` assigns to its lhs. `diff.open_file` has no lhs.

#### Scenario: Diff view uses a reassigned key on reopen
- **WHEN** `diff.close` is reassigned from `q` to `Q` while a view is open, and the view is closed and opened again
- **THEN** `Q` closes the reopened view and `q` is not mapped in its windows

### Requirement: Diff view colours
The view's groups SHALL derive from the gruvbox-material palette:
- `DiffViewAdd`, `DiffViewChange` and `DiffViewDelete` have `bg` = `util.blend(<green|blue|red>, bg0, 0.72 | 0.72 | 0.74)`;
- `DiffViewWord` has `bg` = `util.blend(blue, bg0, 0.5)`;
- `DiffViewGutter*` have `fg` `grey1` on their kind's `bg`;
- `DiffViewArrow*` have `fg` green, blue or red.

The groups SHALL be redefined on `ColorScheme`.

#### Scenario: Diff view highlight colours
- **WHEN** the full config has loaded and `:colorscheme gruvbox-material` runs again
- **THEN**
  - `DiffViewChange` has `bg` `util.blend(blue, bg0, 0.72)` and `DiffViewWord` has `bg` `util.blend(blue, bg0, 0.5)`;
  - `DiffViewGutterAdd` has `fg` `grey1` and `bg` `util.blend(green, bg0, 0.72)`;
  - `DiffViewArrowDelete` has `fg` red;
  - `DiffViewPadding` has `fg` `bg3` and `DiffViewFold` has `fg` `bg5`.

### Requirement: Diff view revert
`diff.apply` SHALL replace the right buffer's lines of the change at the cursor with the change's left lines, as one undo step, without writing the file. The view then re-compares at once. It works in either window. The change at the cursor is the one whose range on the cursor's side contains the cursor line, or whose empty range lies just above it. Off a change, it SHALL do nothing.

#### Scenario: Diff view do reverts a changed line
- **WHEN** the right cursor of the `controller.go` view (`diffgo` fixture) is on line 53 and `do` is pressed in normal mode
- **THEN** right line 53 is `\t\treturn err`, the buffer is modified and not written, and the view has two fragments

#### Scenario: Diff view do uses an immediate buffer edit
- **WHEN** a line is inserted immediately above right line 53 of the `controller.go` view and `do` is pressed there without waiting for a redraw
- **THEN** the freshly compared change is reverted, including the inserted line, and right line 53 is `\t\treturn err`

#### Scenario: Diff view dp reverts a deletion from the left window
- **WHEN** the left cursor of the `controller.go` view is on line 65 and `dp` is pressed in normal mode
- **THEN** right line 66 is `\tc.stats.LastRun.Touch()`, right line 67 is `\treturn nil`, and the left window is still current

#### Scenario: Diff view reverts an insertion as one undo step
- **WHEN** `do` is pressed in normal mode on right line 58 of the `controller.go` view, and then `u`
- **THEN** after `do` the right buffer has 150 lines and no `c.stats.Skipped.Inc()` line. After `u` it has 151 lines again and three fragments.

#### Scenario: Diff view revert off a change does nothing
- **WHEN** `do` is pressed in normal mode on right line 50 of the `controller.go` view
- **THEN** the right buffer's `changedtick` is unchanged and nothing is notified

#### Scenario: Diff view actions reject a file absent from HEAD
- **WHEN** an untracked text file is opened in the diff view and `do` and `<Space>` are pressed on its added lines
- **THEN** the buffer and index are unchanged, and each action notifies that the file cannot be compared with `HEAD`

#### Scenario: Diff view reverting the last change keeps the view open
- **WHEN** a diff view containing one changed line runs `diff.apply` on that line
- **THEN** the view remains open with zero fragments and no folds

### Requirement: Diff view include checkbox
Each change of a file present in `HEAD` SHALL show its index state in its checkbox cell, comparing `HEAD`, the index and the right buffer:
- `☑` (`U+F0132`) when the index holds the change's right lines in place of its left lines;
- `☐` (`U+F0131`) when the index holds its left lines;
- `◪` (`U+F0856`) otherwise.

The states SHALL refresh after each comparison and each toggle.

#### Scenario: Diff view checkboxes follow the index
- **WHEN** `d.txt` of a fresh copy of the `dirty` fixture (line 1 staged, line 3 not) is edited and `diff.open_file` runs
- **THEN** the view has two changes: line 1's checkbox is `☑` and line 3's is `☐`

#### Scenario: Diff view checkbox of a partly staged change
- **WHEN** `<Space>` is pressed in normal mode on right line 53 of the `controller.go` view, right line 53 is then changed to `\t\treturn wrap(err, id)` without writing, and 300 ms pass
- **THEN** the checkbox of the change on line 53 is `◪`

#### Scenario: Diff patch states of a change, an insertion and a deletion
- **WHEN** `require("gleb.diff.patch").state(head, index, right, change)` runs for a changed line, an insertion and a deletion, once with the index equal to `HEAD` and once equal to the right text
- **THEN** each returns `☐` for the first index and `☑` for the second

#### Scenario: Diff patch state of a partly staged change
- **WHEN** `require("gleb.diff.patch").state` runs for a changed line whose index holds a different edit of it, or a staged edit that also covers the next line
- **THEN** both return `◪`

#### Scenario: Diff patch computes checkbox states in one pass
- **WHEN** checkbox states are computed for several changes against one index snapshot
- **THEN** the `HEAD` to index comparison runs once and returns one state per change

### Requirement: Diff view hunk staging
`diff.toggle_include` SHALL unstage the change at the cursor when it is `☑`, and stage it otherwise. It builds the new index text for that change only. It SHALL pipe the `vim.text.diff` patch from the current to the new index text to `git apply --cached --whitespace=nowarn -`, run as an argument list in the repository root, so that other staged changes stay. A failure SHALL notify `Stage failed: <stderr>` or `Unstage failed: <stderr>` at ERROR.

#### Scenario: Diff view Space stages one change
- **WHEN** `<Space>` is pressed in normal mode on right line 53 of the `controller.go` view
- **THEN**
  - `git diff --cached -U0` changes exactly `-\t\treturn err` to `+\t\treturn wrap(err)`;
  - `git diff -U0` still holds the insertion of line 58 and the deletion of old line 65;
  - the checkbox on line 53 is `☑`.

#### Scenario: Diff view Space stages an immediate buffer edit
- **WHEN** right line 53 of the `controller.go` view is changed to `\t\treturn edited(err)` and `<Space>` is pressed there without waiting for a redraw
- **THEN** the index contains `\t\treturn edited(err)`, not the right text from the previous comparison

#### Scenario: Diff view stages a final line without a newline
- **WHEN** the index ends with a newline, the buffer has `noeol nofixeol`, and `<Space>` is pressed on a change touching the final line
- **THEN** the staged blob matches the buffer without a final newline and the checkbox is `☑`

#### Scenario: Diff view unstages a final line with a different newline
- **WHEN** `HEAD` ends with a newline, the buffer has `noeol nofixeol`, and `<Space>` is pressed twice on a change touching the final line
- **THEN** `git diff --cached` is empty and the checkbox is `☐`

#### Scenario: Diff view Space unstages a staged change
- **WHEN** `<Space>` is pressed twice in normal mode on right line 53 of the `controller.go` view
- **THEN** `git diff --cached` is empty and the checkbox on line 53 is `☐`

#### Scenario: Diff view stages an insertion and a deletion separately
- **WHEN** `<Space>` is pressed in normal mode on right line 58 and then on right line 66 of the `controller.go` view
- **THEN** `git diff --cached -U0` adds exactly `\t\tc.stats.Skipped.Inc()` and removes exactly `\tc.stats.LastRun.Touch()`, and line 53 is still unstaged

#### Scenario: Diff patch stages one change
- **WHEN** `require("gleb.diff.patch").update_index(head, index, right, change, include)` stages and unstages a changed line, with an earlier staged insertion, and `make_patch` builds a patch for a file without a final newline
- **THEN**
  - staging yields the right lines in place of the change and keeps the earlier insertion;
  - the patch has two `\ No newline at end of file` markers and passes `git apply --cached --check`.

#### Scenario: Diff view refuses staging over other staged lines
- **WHEN** the index has a staged edit extending beyond the change at the cursor and `<Space>` is pressed on that change
- **THEN** the index is unchanged and `Stage failed: overlaps other staged lines` is notified at ERROR

#### Scenario: Diff patch stages an insertion and a deletion
- **WHEN** `require("gleb.diff.patch").update_index` stages and then unstages an insertion, and then a deletion
- **THEN** staging returns the right text and unstaging returns the `HEAD` text, for each

#### Scenario: Diff view reports a staging failure
- **WHEN** `.git/index.lock` exists in the `diffgo` copy and `<Space>` is pressed in normal mode on right line 53 of the `controller.go` view
- **THEN** a notification starting with `Stage failed: ` is shown at ERROR, `git diff --cached` is empty, and the checkbox stays `☐`

#### Scenario: Diff view staged change matches the approved render
- **WHEN** a `100x30` screen opens the `controller.go` view of a fresh `diffgo` copy and `<Space>` is pressed in normal mode on right line 53
- **THEN** screen rows 2–29 match design.md "Proposed E1 — first change staged", text and colour mask

### Requirement: Diff view moved blocks
The view SHALL request moves from the engine. Each move's left lines and right lines SHALL be tinted `DiffViewMoved` instead of their add or delete tint. The strip SHALL read `→<first right line>` on the original end's first row and `←<first left line>` on the moved end's first row. `diff.jump_move` on a line of either end SHALL focus the other window, on the other end's first line. Off a move, it SHALL do nothing.

#### Scenario: Diff view marks both ends of a moved block
- **WHEN** `internal/user/ids.go` of the `diffgo` fixture is edited and `diff.open_file` runs
- **THEN**
  - left lines 3–9 and right lines 11–17 carry `DiffViewMoved` line highlights;
  - the gutter strip reads `→11` on the row of left line 3, and `←3` on the row of right line 11.

#### Scenario: Diff view gm jumps between the ends of a move
- **WHEN** the right cursor of the `ids.go` view is on line 13, `gm` is pressed in normal mode, and then `gm` again
- **THEN** after the first press the left window is current with its cursor on line 3, and after the second the right window is current with its cursor on line 11

#### Scenario: Diff view gm off a move does nothing
- **WHEN** `gm` is pressed in normal mode on right line 1 of the `ids.go` view
- **THEN** the right window is still current and its cursor is still on line 1

#### Scenario: Diff view moved block matches the approved render
- **WHEN** a `100x30` screen edits `internal/user/ids.go` of a fresh `diffgo` copy, `diff.open_file` runs and the right cursor moves to line 11
- **THEN** screen rows 2–29 match design.md "Proposed E2 — moved block", text and colour mask

### Requirement: Diff view whitespace policy
The actions `diff.ignore_none`, `diff.ignore_trim`, `diff.ignore_whitespaces` and `diff.ignore_whitespaces_chunks` SHALL set the comparison policy (`default`, `trim_whitespaces`, `ignore_whitespaces`, `ignore_whitespaces_chunks`) for every open and later view, and re-compare the open ones. They are radio toggles, available while a diff view is in the current tab page, and unbound. The choice SHALL persist in `stdpath("state")/diff.json`.

#### Scenario: Diff view trim policy hides a trailing space
- **WHEN** a space is appended to right line 50 of the `controller.go` view, 300 ms pass, and `diff.ignore_trim` runs
- **THEN** before the action there is a change at line 50; after it there is none, and the view has its three original fragments

#### Scenario: Diff view trim policy shows a staged checkbox
- **WHEN** `f.txt` changes `a` to `A` and `b` to `b `, `diff.ignore_trim` runs, and `<Space>` is pressed on right line 1
- **THEN** the index contains both changed lines and the displayed change's checkbox is `☑`

#### Scenario: Diff view policy hiding every change keeps the view open
- **WHEN** a file differs from `HEAD` only by ignored whitespace and opens while `ignore_whitespaces` is active
- **THEN** the view remains open with zero fragments and no folds

#### Scenario: Diff view whitespace policy persists
- **WHEN** `diff.ignore_whitespaces` runs in a view, Neovim restarts with the same state directory, and a view opens
- **THEN** `diff.json` holds `"policy":"ignore_whitespaces"`, the new view compares with that policy, and Find Action shows "Ignore Whitespaces" as on

#### Scenario: Diff settings validate diff.json
- **WHEN** `require("gleb.diff.settings").load()` runs with `diff.json` missing, not JSON, holding known values, or holding an unknown `policy`, and `save` then writes a policy and a highlight mode
- **THEN** missing, malformed and unknown state load `{ policy = "default", highlight = "by_word" }`, known values load as written, and `diff.json` holds both saved values

### Requirement: Diff view highlight mode
The actions `diff.highlight_words`, `diff.highlight_split`, `diff.highlight_chars`, `diff.highlight_lines` and `diff.highlight_none` SHALL set the engine mode (`by_word` default, `by_word_split`, `by_char`, `by_line`, `none`) for every open and later view, re-compare the open ones, and persist it in `diff.json`. They are unbound radio toggles, available while a view is current. With `none`, the view SHALL show both texts without tints, padding, folds or gutter marks.

#### Scenario: Diff view line mode drops word highlights
- **WHEN** `diff.highlight_lines` runs while the `controller.go` view is open
- **THEN** neither buffer has a `DiffViewWord` extmark, and line 53 still has its `DiffViewChange` line highlight in both windows

#### Scenario: Diff view no-highlight mode shows plain texts
- **WHEN** `diff.highlight_none` runs while the `controller.go` view is open, and then `]c` is pressed in normal mode in the right window
- **THEN**
  - neither window has a closed fold, a padding row or a `DiffView*` line highlight;
  - the gutter has no `»`;
  - the cursor did not move.

#### Scenario: Diff view highlight mode persists
- **WHEN** `diff.highlight_chars` runs, Neovim restarts with the same state directory, and a view opens
- **THEN** `diff.json` holds `"highlight":"by_char"` and Find Action shows "Highlight Symbols" as on

### Requirement: Diff view leader mappings
The `<Space>` include mapping SHALL not preempt longer `<leader>` mappings in a diff window or another window showing the same right buffer.

#### Scenario: Diff view leader mapping works inside the view
- **WHEN** a normal-mode `<leader>x` mapping is installed and pressed in the right diff window
- **THEN** that mapping runs and the change is not staged

#### Scenario: Diff view leader mapping works in another window of the same file
- **WHEN** a normal-mode `<leader>x` mapping is installed and pressed in the original window showing the diff view's right buffer
- **THEN** that mapping runs and the change is not staged

### Requirement: Diff view action colours
The groups SHALL derive from the gruvbox-material palette and be redefined on `ColorScheme`:
- `DiffViewMoved` has `bg` = `util.blend(aqua, bg0, 0.72)`;
- `DiffViewGutterMoved` has `fg` `grey1` on that `bg`;
- `DiffViewMovedMarker` has `fg` aqua on that `bg`.

#### Scenario: Diff view move colours
- **WHEN** the full config has loaded and `:colorscheme gruvbox-material` runs again
- **THEN** `DiffViewMoved` has `bg` `util.blend(aqua, bg0, 0.72)`, and `DiffViewMovedMarker` has `fg` aqua and the same `bg`

### Requirement: Diff view committed layer
A spec with `committed = true` SHALL be a history comparison: not actionable, no include checkboxes, a read-only left side, and a right side read-only when given as lines but editable when given as `right_buf`. It SHALL draw rows, words, gutters, arrows and moved blocks with the same groups as any other spec; no `DiffViewCommitted*` group SHALL be defined. A read-only right side SHALL get the file's Tree-sitter syntax like the left.

#### Scenario: Diff view draws a committed spec in purple
- **WHEN** from the first of two windows `show(<second>, { path = "c.txt", left = { "one", "two" }, right = { "one", "too", "three" }, labels = { "4ccefde · main", "e325463 · HEAD" }, committed = true })` runs
- **THEN**
  - no purple: no extmark or gutter of either window uses a group whose name starts with `DiffViewCommitted`; the right buffer's line extmarks use `DiffViewChange` on row 2 and `DiffViewAdd` on row 3, and row 2 has a `DiffViewWord` range;
  - the gutter of rows 2 and 3 uses `DiffViewGutterChange` and `DiffViewGutterAdd` and holds no checkbox glyph;
  - both diff buffers have `modifiable` off, and `do` in the right window leaves its lines unchanged.

#### Scenario: Diff view committed colours
- **WHEN** the full config has loaded and `:colorscheme gruvbox-material` runs again
- **THEN** `vim.api.nvim_get_hl(0, { name = <group> })` is empty for `DiffViewCommitted`, `DiffViewCommittedWord`, `DiffViewGutterCommitted` and `DiffViewArrowCommitted`, and `DiffViewChange` still has `bg` `util.blend(blue, bg0, 0.72)`

#### Scenario: Diff view without committed keeps its kind colours
- **WHEN** the same `show` runs without `committed`
- **THEN** row 2 uses `DiffViewChange` and row 3 `DiffViewAdd`, as with `committed`, and the gutter of row 2 holds the include checkbox glyph

#### Scenario: Diff view committed spec keeps a given buffer editable
- **WHEN** a listed buffer of `c.txt` holds `one`, `too`, `three` and from the first of two windows `show(<second>, { path = <its name>, left = { "one", "two" }, right = <its lines>, right_buf = <it>, labels = { "4ccefde · main", "Your version" }, committed = true })` runs, then in the right window `:3delete` runs and 300 ms pass
- **THEN** the right window shows that buffer with `modifiable` on, the buffer holds `one`, `too`, the view has one fragment (`start1 = 1, end1 = 2, start2 = 1, end2 = 2`), and the gutter holds no checkbox glyph

#### Scenario: Diff view committed read-only side has syntax
- **WHEN** from the first of two windows `show(<second>, { path = "c.go", filetype = "go", left = { "package c" }, right = { "package c", "", "var x = 1" }, labels = { "parent", "commit" }, committed = true })` runs
- **THEN** the right buffer has `modifiable` off and `vim.treesitter.highlighter.active[<right buffer>]` is set with language `go`, like the left buffer

### Requirement: Diff view jump to source
`diff.jump_to_source` (`Jump to Source`, `Git | Diff`, plugin `gleb-diff`, `gf` in `settings/keymap.json`) SHALL close the view, edit its working-tree file (`spec.path`) in the window that held its right side (a view with its own tab page: the window it opened from) and focus it, with the cursor on the right line under the diff cursor, or the right line transferred from the left cursor, clamped to the file's line count. Outside view windows `gf` SHALL stay native.

#### Scenario: Diff view gf opens the file at the cursor line
- **WHEN** the `controller.go` view is opened by `diff.open_file`, the left cursor is on line 65 and `gf` is pressed in normal mode
- **THEN** there is 1 tab page, no window shows a `gleb-diff` buffer, the current window edits `internal/user/controller.go` and its cursor is on line 66

#### Scenario: Diff view gf on a read-only right side
- **WHEN** from the first of two windows `show(<second>, { path = <root>/c.txt, left = { "one", "two" }, right = { "one", "too", "three" }, labels = { "parent", "commit" }, committed = true })` runs for a file `c.txt` holding `one`, `two`, focus moves to the right window, its cursor is put on line 3 and `gf` is pressed in normal mode
- **THEN** no `gleb-diff` window remains, the second window is current and edits `c.txt`, and its cursor is on line 2, the file's last line
