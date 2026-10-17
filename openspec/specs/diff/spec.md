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
`lua/gleb/diff/engine/` SHALL hold a `NOTICE` that credits IntelliJ IDEA (© JetBrains s.r.o.) and diffbandit.nvim (© Corey Kaylor) under the Apache License 2.0, plus that license's text. Every ported Lua file and every fixture table translated from upstream tests SHALL start with a header naming its upstream file, project and license, and saying it was modified.

#### Scenario: Ported files carry their attribution
- **WHEN** `NOTICE`, every `.lua` file under `lua/gleb/diff/engine/` and every file under `tests/unit/diff/fixtures/` are read
- **THEN** `NOTICE` names `IntelliJ IDEA`, `JetBrains s.r.o.`, `diffbandit.nvim`, `Corey Kaylor` and `Apache License`, `LICENSE-APACHE-2.0` exists, and each Lua file's first comment names an upstream path and its license
