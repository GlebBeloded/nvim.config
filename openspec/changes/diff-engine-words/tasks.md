## 1. Fixtures and character classes

Scenarios: `diff: Every IntelliJ word case passes`, `diff: Every IntelliJ char case passes`, `diff: Every IntelliJ split case passes`, `diff: IntelliJ character classes hold`

- [x] 1.1 Extend `openspec/changes/diff-engine-lines/drafts/intellij_fixtures.py`, or copy it to this change's `drafts/`, to emit `intellij_words.lua`, `intellij_chars.lua`, `intellij_split.lua` and `intellij_chars_classes.lua`:
  - UTF-16 offsets become byte offsets.
  - Matchings become changed-byte sets (design Decision 7).
  - Every file gets the attribution header.
- [x] 1.2 Write `tests/unit/diff/test_goldens_inner.lua`, asserting the row counts 78, 71 and 27, and see it fail
- [x] 1.3 Write `drafts/unicode_ranges.py` (`UnicodeData.txt` 16.0.0 → BMP letter ranges). Add `lua/gleb/diff/engine/unicode.lua` with those ranges and the `CharacterUtils.kt` tables, and the punctuation, alpha and continuous-script classes in `trim.lua`. Make `diff: IntelliJ character classes hold` pass.

## Agent decisions

- Fixture rows retain their IntelliJ case kind and per-policy expectations so later golden tests can dispatch through the real engine API.
- Unicode tables use flat start/end pairs so generated data stays compact and lookup remains a binary search.

## 2. Words, chars and splitting

Scenarios: `diff: CJK characters are words of their own`, `diff: An emoji change spans its whole character`, `diff: Punctuation separates words`, `diff: Changed words inside a line`, `diff: A deleted word leaves an insertion point`, `diff: A pure insertion has no inner list`, `diff: A whitespace-only insertion has an empty inner list`, `diff: Split mode keeps unrelated lines apart`, `diff: Char mode marks single characters`, `diff: Line mode and no highlighting`

- [ ] 2.1 Write the scenarios in `tests/unit/diff/test_words.lua`, `test_chars.lua`, `test_inner.lua` and `test_split.lua`, and see them fail
- [ ] 2.2 Add `by_word.lua`, `split.lua`, the word chunk optimizer in `optimizer.lua`, and `by_char.lua`:
  - Seed them from diffbandit's `word_diff.lua` (design Decision 1).
  - Port fresh: the TRIM and IGNORE matchers and the char comparisons.
- [ ] 2.3 Add `highlight`, `inner`, `compare_words` and `compare_chars` to `init.lua`, and squash and chunk trimming with `inner = {}` to `policy.lua` (design Decisions 2, 3 and 6)
- [ ] 2.4 Make the four files and `test_goldens_inner.lua` pass

## 3. Limits and columns

Scenarios: `diff: Inner comparison stops after three failures`, `diff: Small fragments keep inner ranges after two failures`, `diff: A deadline during inner comparison keeps the line diff`, `diff: Inner ranges for 500 changed lines stay within budget`, `diff: Squashed word ranges map to buffer columns`, `diff: A range across a newline splits per row`

- [x] 3.1 Write the scenarios in `tests/unit/diff/test_inner_limits.lua`, `test_perf_inner.lua` and `test_columns.lua`, and see them fail. The deadline case wraps `require("gleb.diff.engine.by_word").compare_and_split` to flip its fake clock.
- [x] 3.2 Add `MAX_BAD_LINES`, `MAX_INNER_BYTES` and the inner-phase deadline (design Decision 4), and `inner_columns`
- [x] 3.3 Make the three files pass. If the perf bound fails, optimise; never loosen it.

## 4. Invariants, attribution, check

Scenarios: `diff: Random texts keep IntelliJ's inner invariants`

- [x] 4.1 Write the scenario in `tests/unit/diff/test_invariants_inner.lua` (design Decision 7) and see it fail if anything breaks; fix the engine, never the invariant
- [x] 4.2 Add the Unicode Character Database line to `NOTICE` and headers to the new files. `diff: Ported files carry their attribution` (from `diff-engine-lines`) must still pass.
- [ ] 4.3 Run `make check`

## Stuck

- Task: 2. Words, chars and splitting.
- Probe output: whole-text word ranges matched the four failing fixtures, while the line path either shifted the trailing-newline range or lost `inner` after `refine_edge_lines` introduced a pure sub-block that squash propagated as `inner = nil`.
- Attempt 1: restored the missing UTF-8 word, char and splitter modules from the upstream algorithms and merged the saved squash/optimizer work with inner limits. All 27 split goldens passed, as did the prior exact char TRIM/IGNORE examples, but eight `lines_inner` word rows failed because the restored edge-refinement heuristic rewrote native splitter blocks.
- Attempt 2: removed edge refinement and used the splitter's native blocks. The line-inner cause was removed, but split goldens `SplitComparisonUtilTest.kt:67` and `:72` collapsed expected `{ 1, 2, 0, 1 }` plus `{ 2, 3, 1, 1 }` blocks into `{ 1, 3, 0, 1 }`.
- Saved implementation: `/Users/hlebbeladzed/.archon/workspaces/GlebBeloded/nvim.config/artifacts/runs/b5f3c5b8-bb9a-46d3-a147-dc84204666ea/stuck-attempt.diff`.
