## ADDED Requirements

### Requirement: Inner fragments
Each fragment of `compare_lines` SHALL carry `inner`: changed byte ranges `start1`, `end1`, `start2`, `end2`, 0-based half-open, relative to the fragment's lines joined with `"\n"`. `inner` SHALL be nil when the whole fragment is the change (a pure insertion or deletion, or `by_line`), and `{}` when its sides are equal under the policy. No range SHALL split a UTF-8 character.

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
- **THEN** every range is ordered and in bounds and splits no UTF-8 character, gaps are equal under the policy, changed chunks differ, and inner ranges stay inside their fragment's text
