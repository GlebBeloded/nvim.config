## Context

See proposal.md (Why). Research, 2026-10-17:

- **Sources.** The implementer fetches them into a temp dir outside the repo. They are data: read them, never build or run them.

  | Source | Pin | Fetch |
  |---|---|---|
  | IntelliJ Community, Apache-2.0 | `d422387398cbecf45702238cfee4acc71bd2b97d` | `git clone --filter=blob:none --sparse https://github.com/JetBrains/intellij-community`, then `git sparse-checkout set platform/util/diff platform/diff-impl/src/com/intellij/diff/comparison platform/diff-impl/tests/testSrc/com/intellij/diff` |
  | diffbandit.nvim, Apache-2.0 | `7e1e5b8b080e9784fcd27180c25c8733d2fff758` | `git clone https://github.com/CoreyKaylor/diffbandit.nvim` |

- **IntelliJ's line pipeline** (`platform/util/diff/src/com/intellij/diff/comparison/ByLineRt.kt`, `doCompare`):
  - For DEFAULT and TRIM_WHITESPACES:
    1. Convert the lines to IGNORE_WHITESPACES.
    2. `compareSmart`: diff only the "big" lines, those with more than `UNIMPORTANT_LINE_CHAR_COUNT` = 3 non-space characters. Then `SmartLineChangeCorrector` re-diffs the gaps with every line.
    3. `LineChunkOptimizer` slides ambiguous chunks toward empty lines.
    4. `correctChangesSecondStep` realigns the IW-matched blocks so that exactly-equal lines pair up. The source comment's example: `.{ ..{ ...{` vs `..{ ...{` deletes only the first line.
  - For IGNORE_WHITESPACES: `compareSmart`, then `optimizeLineChunks`, then `expandRanges`, which trims IW-equal lines off each change.
  - The LCS comes from `util/diff/Diff.kt` `buildChanges`:
    1. Trim the common prefix and suffix. When one side is then empty, the result is one change.
    2. `Reindexer.discardUnique`.
    3. `MyersLCS.executeWithThreshold`, with threshold `max(20000 + 10·⌊√(n1+n2)⌋, DiffConfig.DELTA_THRESHOLD_SIZE = 20000)`, capped at `n1+n2`. It throws `FilesTooBigForDiffException` when the edit distance passes that.
    4. On that exception, `PatienceIntLCS.execute(failOnSmallReduction = true)`. Each level trims the common prefix and suffix, then anchors on `UniqueLCS`.
    5. Where there are no unique anchors, `MyersLCS.executeLinear` (never throws).
    6. `checkReduction` throws again unless a sub-problem is under half of either side. This check is armed for the first two levels.
  - `DiffIterableUtil.diff` turns the exception into `DiffTooBigException`.
- **Ignore policies.** IntelliJ's UI has five (`diff-impl/.../tools/util/base/IgnorePolicy.java`). `IGNORE_WHITESPACES_CHUNKS` ("Ignore whitespaces and empty lines") is the IGNORE_WHITESPACES comparison plus `ComparisonManagerImpl.processBlocks(trim = true)`. That drops the leading and trailing fragments of each adjoining run whose texts are equal ignoring whitespace. `FORMATTING` and the language-specific policy are out of scope.
- **What diffbandit.nvim already ported, and what this change ports fresh.**

  | diffbandit file | Seeds | Port fresh / fix |
  |---|---|---|
  | `lua/diffbandit/diff/myers_lcs.lua` (`myers_lcs`, `discard`, `reindex`, `M.diff`) | `lcs.lua`: `MyersLCS`, `Reindexer`, `Diff.buildChanges` | `PatienceIntLCS` and `UniqueLCS` (diffbandit re-runs unbounded Myers instead); the too-big signal; deadline checks in the Myers `d` loop and in the Patience recursion |
  | `lua/diffbandit/diff/smart_align.lua` (`compare_smart`, `optimize_line_chunks`, `correct_changes_second_step`, `expand_*`, `new_change_builder`) | `by_line.lua`, `optimizer.lua` (`LineChunkOptimizer`), `trim.lua` (`expand*`), `ranges.lua` (change builders) | policy-aware equality and hashing (`ComparisonUtil.isEquals`/`hashCode`), TRIM_WHITESPACES, the whitespace set (space, tab, newline; diffbandit's `%s` also strips `\r\v\f`), non-space counts in code points (diffbandit counts bytes) |
  | `lua/diffbandit/diff/word_diff.lua` | `diff-engine-words` | — |
  | `lua/diffbandit/diff/init.lua`, `document.lua`, `pair.lua` | nothing (viewer glue, cache) | — |

  Fresh in this change: `policy.lua` (the four ignore policies, `processBlocks` trim), the xdiff fallback, `init.lua` (public API, limits).
- **Alternatives considered** (proposal, Impact):
  - diffbandit: 5 oracle goldens, no TRIM/IGNORE/char/Patience. Its UI is its own.
  - vscode-diff.nvim (in use today): VS Code's algorithm.
  - Neovim's `vim.text.diff`: xdiff Myers, minimal, patience or histogram, with no line heuristics.
  - Nothing in the Neovim ecosystem ports IntelliJ's TRIM or IGNORE policies, or its LineChunkOptimizer.

## Goals / Non-Goals

**Goals:**
- IntelliJ's line diff, result for result, on IntelliJ's own test expectations.
- A pure, typed library that later changes (words, moves, viewer) extend without changing its shapes.
- A bounded comparison time that still yields a usable line diff.

**Non-Goals:**
- Inner fragments, moves, UI (later changes).
- Three-way merge and conflict resolution (diffview keeps merges).
- Ignored text ranges, `FORMATTING`, word-first mode.

## Decisions

1. **Layout** (rule 1.3, PLAN module layout). Everything lives under `lua/gleb/diff/engine/`. Each file is `local M = {}` with LuaCATS types, and no file requires a plugin.

   | File | Holds | IntelliJ source |
   |---|---|---|
   | `init.lua` | `compare_lines`, option defaults, the fallback chain | `ComparisonManagerImpl.compareLines` |
   | `lcs.lua` | `diff(ids1, ids2, ctx)` → changed ranges | `Diff.kt`, `MyersLCS.kt`, `Reindexer.kt`, `PatienceIntLCS.kt`, `UniqueLCS.kt` |
   | `ranges.lua` | ranges, change builders, unchanged/changed iteration | `Range.kt`, `iterables/DiffIterableUtil.kt`, `ExpandChangeBuilder` |
   | `by_line.lua` | the line pipeline | `ByLineRt.kt`, `ChangeCorrector.kt` (`SmartLineChangeCorrector`) |
   | `optimizer.lua` | `LineChunkOptimizer` (`diff-engine-words` adds the word optimizer) | `ChunkOptimizer.kt` |
   | `trim.lua` | `expand*`, `trim*`, whitespace class | `TrimUtil.kt` |
   | `policy.lua` | equality and hash keys per policy, `ignore_whitespaces_chunks` trimming | `ComparisonUtil.kt`, `IgnorePolicy.java`, `ComparisonManagerImpl.processBlocks` |

   - Lines are interned to integer ids through a Lua table keyed by the policy's key string, which replaces IntelliJ's `Enumerator` and its hashes:
     - `default`: the line itself.
     - `trim_whitespaces`: the line without leading and trailing whitespace.
     - `ignore_whitespaces`: the line without any whitespace.
   - Equal keys mean equal lines, so no hash collisions need handling.
2. **Public API** (`gleb.diff.engine`). Every range is 0-based and half-open. Side 1 is the old text, side 2 the new.

   ```lua
   ---@alias gleb.diff.Policy "default"|"trim_whitespaces"|"ignore_whitespaces"|"ignore_whitespaces_chunks"

   ---@class gleb.diff.Limits
   ---@field timeout_ms? integer    deadline for the whole call (default TIMEOUT_MS = 1000)
   ---@field clock? fun(): number   milliseconds; default vim.uv.hrtime() / 1e6 (tests inject a fake)
   ---@field myers_threshold? integer  overrides IntelliJ's max(20000 + 10·⌊√(n1+n2)⌋, DELTA_THRESHOLD_SIZE)

   ---@class gleb.diff.Options
   ---@field policy? gleb.diff.Policy   default "default"
   ---@field limits? gleb.diff.Limits

   ---@class gleb.diff.LineFragment
   ---@field start1 integer  first changed line of side 1 (0-based)
   ---@field end1 integer    exclusive; start1 == end1 is an insertion point
   ---@field start2 integer
   ---@field end2 integer

   ---@class gleb.diff.Result
   ---@field fragments gleb.diff.LineFragment[]  ordered, disjoint, never empty on both sides
   ---@field too_big boolean    LCS gave up: fragments come from the xdiff fallback
   ---@field timed_out boolean  deadline passed: fragments come from the xdiff fallback

   ---@param lines1 string[]  lines without newline characters (nvim_buf_get_lines)
   ---@param lines2 string[]
   ---@param opts? gleb.diff.Options
   ---@return gleb.diff.Result
   function M.compare_lines(lines1, lines2, opts) end
   ```

   - `diff-engine-words` adds an `inner` field to `LineFragment` and a `highlight` option. `diff-engine-moves` adds `moves`. Both are additive, so this change's scenarios stay valid.
   - The engine never mutates its inputs.
   - Lines follow IntelliJ's line model: the text `"x\n"` is the two lines `{ "x", "" }`. So fixtures split IntelliJ texts on `"\n"` (plain), which yields exactly IntelliJ's line count.
3. **Policies.**
   - Whitespace is IntelliJ's `isSpaceEnterOrTab`: space, tab and newline.
   - Non-space characters are counted in UTF-8 code points, for the unimportant-line rule (`> 3` is "big").
   - `ignore_whitespaces_chunks` runs the `ignore_whitespaces` comparison. Then, for each run of adjoining fragments, it drops leading and trailing fragments whose two texts (the lines joined with `"\n"`) are equal once all whitespace is removed. That is IntelliJ's `processAdjoining` with `trim = true`.
4. **Limits and fallback chain.** One context per call carries the deadline, `start + timeout_ms` on `limits.clock`.
   1. Myers checks the clock once per `d` step and Patience once per recursion. The correctors and the optimizer check it once per change.
   2. Myers past its threshold → Patience.
   3. Patience fails `checkReduction` → too big.
   4. Too big or past the deadline → the whole comparison falls back to `vim.text.diff(text1, text2, { result_type = "indices", algorithm = "histogram" })`:
      - The texts are the lines joined with `"\n"` plus a final `"\n"`.
      - Each `{a, ca, b, cb}` is converted to a 0-based half-open fragment: `start = a - 1` when the count is > 0, else `a`.
      - The result has `too_big` or `timed_out` set.
   - Constants sit at the top of `init.lua` and `lcs.lua` (rule 4.3):
     - `DELTA_THRESHOLD_SIZE = 20000`
     - `UNIMPORTANT_LINE_CHAR_COUNT = 3`
     - `TIMEOUT_MS = 1000`
   - `MAX_BAD_LINES = 3` arrives with inner fragments in `diff-engine-words`.
5. **Performance bound.**
   - The input generator, defined here so that tests carry no magic data, builds `lines1` with 5,000 lines. Line `i` (1-based) is:
     - `""` when `i % 10 == 0`;
     - `"end"` when `i % 10 == 9`;
     - otherwise `string.format("local value_%d = compute(%d, \"item %d\")", i, i * 7, i)`.
   - `lines2` is a copy with three edits:
     - every line with `i % 100 == 55` has `compute` replaced by `calculate` (50 edits);
     - after every line with `i % 500 == 1`, `"-- inserted"` is inserted (10 insertions);
     - every line with `i % 500 == 275` is deleted (10 deletions).
   - All 70 edits land on generated `local` lines, at least 20 lines apart, so they give exactly 70 fragments.
   - The bound: `compare_lines(lines1, lines2)` with default options returns, as the median of 3 runs in a bare child after one warm-up run, in under 100 ms × `H.load_factor()`.
   - The same bound must still hold after `diff-engine-words` turns on by-word inner fragments by default. The 50 one-line inner comparisons are cheap.
   - Expected cost: interning 10k lines, plus Myers with D ≈ 140 on about 10k ids, is a few milliseconds in LuaJIT.
6. **Fixtures, no JVM.** IntelliJ's Kotlin test DSL (`ComparisonUtilTestBase.kt`) is translated once into Lua tables. One converter, `openspec/changes/diff-engine-lines/drafts/intellij_fixtures.py`, reads the pinned `.kt` files as text and writes the tables. It is committed with the change and archived with it. The generated tables are committed under `tests/unit/diff/fixtures/`.
   - **DSL semantics the converter must honour:**
     - `_` in a test text is a newline (`parseSource`), unless `.plainSource()`.
     - `mod(l1, l2, c1, c2)` is `{l1, l1 + c1, l2, l2 + c2}`; `del` and `ins` are the same with an empty side.
     - A matching string like `("--_---" - "---_----")` marks changed lines. Split it on `_`/`*`: a segment with any character other than space or `_` marks its line, and `*` marks an empty line.
     - Expectations fall back IGNORE → TRIM → DEFAULT. The converter stores them already resolved for each policy it ran (`testAll` = all three, `testDefault`/`testTrim`/`testIgnore` = one).
   - **Table shape:**

     ```lua
     -- Translated from intellij-community (Apache-2.0, © JetBrains s.r.o.) at d4223873:
     -- platform/diff-impl/tests/testSrc/com/intellij/diff/comparison/LineComparisonUtilTest.kt
     -- Modified: Kotlin DSL rewritten as Lua data.
     return {
       {
         source = "LineComparisonUtilTest.kt:126",
         lines1 = { "x", "y", "z" },
         lines2 = { "n", "k", "y" },
         expect = {
           default = { fragments = { { 0, 1, 0, 2 }, { 2, 3, 3, 3 } } },
           trim_whitespaces = { fragments = { { 0, 1, 0, 2 }, { 2, 3, 3, 3 } } },
           ignore_whitespaces = { fragments = { { 0, 1, 0, 2 }, { 2, 3, 3, 3 } } },
         },
       },
       -- matching form: { changed1 = { 0, 1 }, changed2 = { 1 } } (changed line indices)
     }
     ```

   - **Cases ported here:**

     | Source (`platform/diff-impl/tests/testSrc/com/intellij/diff/comparison/`) | Cases | Table |
     |---|---|---|
     | `LineComparisonUtilTest.kt` (23 test functions) | 69 `lines {}` | `intellij_lines.lua` |
     | `ComparisonUtilTest.kt` | 33 `doTestTrim` (TRIM equality, `policy.lua`) and 12 `doTestLineFragment` (line ranges only; offsets don't exist here) | `intellij_equality.lua` |
     | diffbandit `tests/specs/40_oracle.lua` (captured from IntelliJ util-diff 261.26222.72) | 5 hunk goldens, converted from 1-based `{type, start, count}` | `diffbandit_oracle.lua` |
     | `ComparisonUtilAutoTest.kt` | 9 randomized functions → one property test | generated in `test_invariants.lua` |

     The one `splitter {}` case in `LineComparisonUtilTest` moves to `diff-engine-words`.
   - **Property test.**
     - It uses its own 32-bit LCG (seed `20261017`): 30 runs, text length uniform in 0..300.
     - IntelliJ's two alphabets: `\n \n \t ␠ ␠ . < ! i j k l`, and with emoji `\n \n \t ␠ ␠ . < !` 😂 🤫 🔫 🧒 `m n o p`.
     - It runs all four policies and checks IntelliJ's line invariants:
       - fragments are ordered and disjoint, and none is empty on both sides;
       - ranges lie within the inputs;
       - the gaps between fragments are equal: exactly for `default`, with the policy's key otherwise;
       - for `ignore_whitespaces`, when both first lines or both last lines of a fragment are big, they differ under the policy ("can't trim").
7. **Licensing.**
   - `lua/gleb/diff/engine/NOTICE` reproduces IntelliJ's `NOTICE.txt` line ("This software includes code from IntelliJ IDEA / Copyright (C) JetBrains s.r.o. / https://www.jetbrains.com/idea/"). It adds "Portions derived from diffbandit.nvim, Copyright Corey Kaylor, Apache License 2.0" and points to `LICENSE-APACHE-2.0` (the verbatim license text), as Apache-2.0 §4(a) and §4(d) require.
   - Each ported file starts with a 3-line header (rule 9.1 still applies below it):

     ```lua
     -- Lua port of intellij-community platform/util/diff/src/com/intellij/diff/comparison/ByLineRt.kt
     -- (Apache-2.0, © JetBrains s.r.o.), seeded from diffbandit.nvim lua/diffbandit/diff/smart_align.lua
     -- (Apache-2.0, © Corey Kaylor). Modified: rewritten in Lua; see NOTICE.
     ```

     That covers the §4(b) notice for modified files. Fixture files carry the same kind of header.
8. **Test layers.**
   - Everything here is a unit test in a bare child (`child.start_bare()`), since the engine has no dependencies.
   - Timing uses `vim.uv.hrtime()` inside the child.
   - Fixture-driven scenarios run every table row in one case, and a failure names the row's `source`.

## Risks / Trade-offs

- **Translation errors in the converter.**
  - Risk: a wrong conversion silently changes the expectations.
  - Mitigation: the converter also prints the per-file counts above, and `test_goldens.lua` asserts those counts. Every row keeps its `source` line, so a mismatch can be checked against the Kotlin.
- **Fallback divergence.** Too-big or timed-out comparisons show xdiff's histogram ranges, not IntelliJ's. They are flagged, so `diff-view` can tell the user.
- **Code points vs UTF-16.** Counts differ from IntelliJ only for astral characters (emoji), and only in the 3-character unimportant-line threshold.
- **LuaJIT speed.** If the 100 ms bound fails on the host, the first lever is fewer string allocations in interning, not a looser bound. Rule: never weaken a test.

## Renders

None. This change has no visible UI: it adds a pure library with no caller yet. The viewer's Current and Proposed renders belong to `diff-view`.
