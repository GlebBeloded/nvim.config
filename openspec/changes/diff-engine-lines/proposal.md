## Why

Kind: feature

The user wants IntelliJ's diff in Neovim and wants to own the UI completely. The three viewers in the config today (Differ, vscode-diff, diffview) each come with their own engine, and none of them computes the diff the way IntelliJ does. IntelliJ's engine is not available in Lua yet. diffbandit.nvim ported part of it (Myers + Reindexer, ByLine's smart matching, part of ByWord), but it skips the Patience fallback, the TRIM and IGNORE whitespace policies, char mode and any size bound. It also deviates in small ways: `\r` counts as whitespace, and important lines are counted in bytes.

This change is the first of three engine changes. It ports the line level of IntelliJ's comparison engine as a pure Lua library, `lua/gleb/diff/engine/`, and creates the `diff` capability. Later changes build on it: words and chars (`diff-engine-words`), moves (`diff-engine-moves`), then the viewer (`diff-view`).

## What Changes

- **New pure library `lua/gleb/diff/engine/`.** It has no plugin requires (rule 1.3) and is LuaCATS-typed. Its public entry point is `require("gleb.diff.engine").compare_lines(lines1, lines2, opts)`. The result shapes are in design.md, Decision 2.
- **LCS** (`lcs.lua`):
  - IntelliJ's `Diff.buildChanges`: it trims the common prefix and suffix, discards elements unique to one side (`Reindexer`), then runs `MyersLCS` with IntelliJ's threshold.
  - Above that threshold, `PatienceIntLCS` with `UniqueLCS` runs instead, as in IntelliJ.
  - When Patience can't halve the problem, the comparison is "too big".
- **ByLine** (`by_line.lua`, `optimizer.lua`, `trim.lua`, `ranges.lua`):
  - `compareSmart`: lines with 3 or fewer non-space characters are unimportant and are left out of the first matching pass.
  - `SmartLineChangeCorrector`.
  - the whitespace-insensitive first pass, then `correctChangesSecondStep` (exact realignment).
  - `LineChunkOptimizer`: an ambiguous insertion slides to a blank-line boundary.
  - `expandRanges` for the ignore policy.
- **Whitespace policies** (`policy.lua`), the four IntelliJ ignore policies:
  - `default`
  - `trim_whitespaces`
  - `ignore_whitespaces`
  - `ignore_whitespaces_chunks`: ignore whitespace, then drop the changes that are only whitespace or empty lines (IntelliJ's "Ignore whitespaces and empty lines").
- **Bounded time:**
  - Every call has a deadline, `limits.timeout_ms`, default 1000 ms.
  - When the line comparison is too big or misses the deadline, the result falls back to Neovim's built-in xdiff (histogram) line ranges, with `too_big` or `timed_out` set. The caller always gets a usable line diff.
- **Golden fixtures without a JVM.** IntelliJ's line test expectations are translated once into Lua tables under `tests/unit/diff/fixtures/`:
  - `LineComparisonUtilTest`, 69 cases.
  - `ComparisonUtilTest`, 33 trim-equality and 12 line-fragment cases.
  - diffbandit's 5 IntelliJ-oracle goldens.
  - The invariants of `ComparisonUtilAutoTest`, as a fixed-seed property test.
- **Attribution:**
  - The engine folder gets a `NOTICE` (IntelliJ IDEA © JetBrains s.r.o., Apache-2.0; diffbandit.nvim © Corey Kaylor, Apache-2.0) and a copy of the Apache-2.0 text, `LICENSE-APACHE-2.0`.
  - Every ported file and every fixture file starts with a header naming its upstream file and license, and noting that it was modified (a Lua port).

## Capabilities

### New Capabilities
- `diff`: IntelliJ-style comparison and, from `diff-view` on, the two-pane viewer. This change adds the line-comparison requirements.

### Modified Capabilities
- none

## Impact

- Code: new `lua/gleb/diff/engine/` (`init.lua`, `lcs.lua`, `ranges.lua`, `by_line.lua`, `optimizer.lua`, `trim.lua`, `policy.lua`, `NOTICE`, `LICENSE-APACHE-2.0`). Nothing requires it yet; `diff-view` is the first consumer.
- Tests: unit only, all in a bare child (`tests/unit/diff/`):
  - `test_lines.lua`
  - `test_policies.lua`
  - `test_limits.lua`
  - `test_goldens.lua`: the IntelliJ and diffbandit fixture tables.
  - `test_invariants.lua`
  - `test_notice.lua`
  - `test_perf.lua`
  - Fixture tables: `tests/unit/diff/fixtures/intellij_lines.lua`, `intellij_equality.lua`, `diffbandit_oracle.lua`.
- Docs: `docs/architecture.md` module map gains a `diff/` row (the engine; the viewer follows in `diff-view`).
- Plugins: none added or removed. The engine is ported code, not a dependency. Alternatives checked (design.md, Context):
  - diffbandit.nvim: an incomplete port, and a UI the user doesn't want.
  - vscode-diff.nvim: VS Code's algorithm in C, not IntelliJ's.
  - Neovim's `vim.text.diff`/xdiff: Myers, minimal or histogram, without IntelliJ's line heuristics. It is used only as the too-big fallback.
- Core keymaps: none.
- Unchanged scenarios: none pinned. The change adds a new capability and touches no existing module, keymap or plugin.
- Out of scope:
  - Word and char inner fragments, highlight modes and change splitting (`diff-engine-words`).
  - Move detection (`diff-engine-moves`).
  - The viewer and actions (`diff-view`, `diff-view-actions`).
  - Three-way comparison, merge and conflict resolution (`ComparisonMergeUtil`, `MergeResolveUtil`, `ByLineRt.merge`). Merges keep using diffview.
  - IntelliJ's `FORMATTING` and language-specific ignore policies, ignored text ranges (`compareLinesWithIgnoredRanges`) and the word-first registry mode (`compareLinesWordFirst`).
  - End-of-file newline differences: the engine compares line arrays as Neovim holds them.

## Decision (user, 2026-10-17)

- Engine: "port IDEA one, if it's not ported to lua yet". From the options, the user picked "Port IntelliJ's engine, seeded from diffbandit's Lua".
- "is diffbanding perfect? I want to own ui 100%".
- "I'm used to Idea", "I like IDEA IDE diff more".

## Agent decisions

- **Fallback when the comparison is too big or too slow.** IntelliJ only shows "too big" in that case. Here the result falls back to xdiff histogram line ranges, flagged `too_big` or `timed_out`, because a viewer is more useful with a coarse diff than with none. The deadline (1000 ms, in `limits`) is new: IntelliJ runs comparisons in a cancellable background task, and Lua blocks the editor while it compares.
- **`limits` option.** IntelliJ's constants (`DELTA_THRESHOLD_SIZE` 20000, `MAX_BAD_LINES` 3, `UNIMPORTANT_LINE_CHAR_COUNT` 3) are `UPPER_SNAKE` defaults. `opts.limits` can override them for each call (`myers_threshold`, `timeout_ms`, `clock`), so the fallbacks are testable without huge inputs.
- **`ranges.lua`.** It is added to the planned layout and holds IntelliJ's `Range`, `DiffIterableUtil` and change builders, which every other engine file uses.
- **Whitespace and counts.** Whitespace is IntelliJ's set: space, tab and newline; `\r` is text. diffbandit counts `\r` as whitespace. Non-space characters are counted in UTF-8 code points, where IntelliJ counts UTF-16 units: the two agree everywhere in the BMP.
