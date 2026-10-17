## Why

Kind: feature
Depends: diff-engine-lines

IntelliJ's diff shows what changed inside a line, not only which lines changed. Its default "Highlight words" mode compares words within each changed block. It splits a block into the lines that really belong together, and it treats whitespace by the selected policy. `diff-engine-lines` ports only the line level. diffbandit.nvim ported ByWord for the DEFAULT policy only. It has no char mode, no TRIM or IGNORE word matching, and a simplified script detector that glues emoji and CJK punctuation into neighbouring words.

This change ports IntelliJ's word and char levels on top of the line engine, so `diff-view` can draw IntelliJ's inner highlights.

## What Changes

- **Inner fragments.**
  - Each line fragment from `compare_lines` gains an `inner` list of changed byte ranges, relative to the fragment's comparison text (its lines joined with `"\n"`, plus the `"\n"` ending its last line when another line follows on that side).
  - `inner = nil` means the whole fragment is the change: a pure insertion or deletion, or a mode without inner fragments.
  - `inner = {}` means the sides differ only in what the policy ignores, as in IntelliJ.
- **Highlight modes** (`opts.highlight`), IntelliJ's five:

  | Mode | IntelliJ name | Inner fragments | Squash |
  |---|---|---|---|
  | `by_word` (default) | Highlight words | words | yes: adjoining fragments merge into one |
  | `by_word_split` | Highlight split changes | words | no: a block is split into the line groups that belong together |
  | `by_char` | Highlight symbols | chars | yes |
  | `by_line` | Highlight lines | none | yes |
  | `none` | Do not highlight | none, and no fragments | — |

- **Ports:**
  - `ByWordRt` (`by_word.lua`): the UTF-8 tokenizer, `compare`, `compareAndSplit`, the punctuation and whitespace matchers for all three policies.
  - `LineFragmentSplitter` (`split.lua`).
  - The word chunk optimizer (`optimizer.lua`).
  - `ByCharRt` (`by_char.lua`): `compareTwoStep`, `compareTrimWhitespaces`, `compareIgnoreWhitespaces`, punctuation.
  - IntelliJ's character classes (`trim.lua`, `unicode.lua`).
  - `ComparisonManagerImpl`'s inner-fragment and squash logic (`init.lua`).
- **Whole-text API.** `compare_words(text1, text2, opts)` and `compare_chars(text1, text2, opts)` return byte-range fragments, as IntelliJ's `compareWords` and `compareChars` do.
- **Highlight helper.** `inner_columns(fragment, side, lines)` maps a fragment's inner ranges to `{ row, col_start, col_end }` byte columns of one side, for extmarks.
- **Limits:**
  - After 3 inner comparisons fail (IntelliJ's `MAX_BAD_LINES`), the remaining fragments keep `inner = nil`.
  - A comparison fails when it is too big, or when a side exceeds `limits.max_inner_bytes` (default 50,000 bytes).
  - The call deadline also bounds the inner phase.
- **Golden fixtures,** translated by the converter from `diff-engine-lines`:
  - `WordComparisonUtilTest`: 58 `lines_inner` and 20 `words` cases.
  - `CharComparisonUtilTest`: 65 `chars`, 3 `chars_raw` and 3 `chars_smart` cases.
  - `SplitComparisonUtilTest` (26 cases) and the one splitter case of `LineComparisonUtilTest`.
  - `TrimUtilTest`'s character classes.
  - The word, char and inner-fragment invariants of `ComparisonUtilAutoTest`, with emoji.
- **Attribution:** `NOTICE` adds the Unicode Character Database (Unicode License v3), which the generated letter-category table comes from.

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `diff`: adds the requirements for inner fragments, highlight modes, splitting, whole-text word and char comparison, inner limits, the column helper, and the word and char goldens.

## Impact

- Code:
  - New: `lua/gleb/diff/engine/by_word.lua`, `by_char.lua`, `split.lua` and `unicode.lua`.
  - Changed: `optimizer.lua` (word chunk optimizer), `trim.lua` (punctuation, alpha and continuous-script classes), `policy.lua` (squash), `init.lua` (the `highlight` option, `inner`, `compare_words`, `compare_chars`, `inner_columns`, `MAX_BAD_LINES`), `NOTICE`.
  - Nothing outside the engine changes.
- Tests: unit tests in a bare child (`tests/unit/diff/`):
  - `test_inner.lua`
  - `test_split.lua`
  - `test_words.lua`
  - `test_chars.lua`
  - `test_inner_limits.lua`
  - `test_columns.lua`
  - `test_goldens_inner.lua`
  - `test_invariants_inner.lua`
  - `test_perf_inner.lua`
  - Fixture tables `intellij_words.lua`, `intellij_chars.lua`, `intellij_split.lua` and `intellij_chars_classes.lua`.
- Plugins: none.
- Core keymaps: none.
- Unchanged scenarios: none pinned, since no existing module changes.
  - The `diff` scenarios of `diff-engine-lines` still hold: `inner` and `highlight` are additive, and every line range they assert is the same with inner fragments on.
- Out of scope:
  - The viewer and its highlight groups (`diff-view`).
  - Moves (`diff-engine-moves`).
  - IntelliJ's word-first mode (`compareLinesWordFirst`, the registry flag `diff.by.word.deprioritize.line.differences`, `LineUplifterTest`).
  - Explicit-range comparison (`BlocksComparisonUtilTest`, via `SimpleTextDiffProvider`).
  - Ignored text ranges (`IgnoreComparisonUtilTest`).
  - Three-way word and char merges (`WordMergeComparisonUtilTest`, `CharComparisonMergeUtilTest`, `MergeResolveUtil`).

## Decision (user, 2026-10-17)

- Engine: "port IDEA one, if it's not ported to lua yet". The user picked "Port IntelliJ's engine, seeded from diffbandit's Lua".
- "is diffbanding perfect? I want to own ui 100%".
- "I'm used to Idea", "I like IDEA IDE diff more".

## Decision (auditor, 2026-10-17, no stubs, shipped tests)

- `by_word`, `by_char` and the split/squash step implement IntelliJ's ByWord/ByChar (DEFAULT plus the TRIM/IGNORE corrections) in full; no task is ticked against a placeholder (one prefix-to-suffix span); tasks ticked on the placeholder are unticked and redone on the real modules.
- The diff-engine-lines scenarios keep holding by asking for `highlight = "by_line"` (or comparing line ranges only) in their tests; that test edit is part of this change.
- Inner goldens, limits and perf tests fail on a fallback: a nil or multi-fragment `inner` is a failure, never "no changes"; the perf case edits several words per line so the word LCS actually runs; the invariants test adds a minimality check (no range spans an unchanged word under DEFAULT).
- `policy.squash` tracks running lengths (linear), no re-concatenation per merge.

## Agent decisions

- **Byte offsets, not characters.**
  - Inner ranges are 0-based half-open byte offsets into UTF-8 text.
  - Why:
    - Neovim's extmarks and highlights take byte columns.
    - Lua strings index bytes.
    - The tokenizer walks code points, so a range never splits a character.
  - IntelliJ's UTF-16 offsets in the fixtures are converted to bytes once, by the converter.
- **`by_word` is the default,** as in IntelliJ.
- **`max_inner_bytes` (50,000) is new.** IntelliJ bounds inner work only through the Myers threshold. A Lua comparison blocks the editor, so a huge rewritten block gets line highlights only.
- **Character classes.** IntelliJ's `Char.category` comes from the JVM. This change generates a BMP letter-category range table from Unicode 16.0, the version of `CharacterUtils.kt`'s tables, instead of diffbandit's hand-picked CJK ranges.
