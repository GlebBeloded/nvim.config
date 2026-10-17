## 1. Sources, converter and fixtures

Scenarios: `diff: Every IntelliJ line case passes`, `diff: IntelliJ trim equality and line fragments hold`, `diff: diffbandit oracle goldens pass`

- [x] 1.1 Fetch the pinned sources into a temp dir outside the repo (design.md, Context, Sources). Write `drafts/intellij_fixtures.py`, which reads the `.kt` test files as text, applies the DSL semantics of design Decision 6 and writes `tests/unit/diff/fixtures/intellij_lines.lua` and `intellij_equality.lua`, each with the attribution header. Hand-convert diffbandit's 5 goldens into `diffbandit_oracle.lua` (1-based hunks to 0-based ranges).
- [x] 1.2 Write `tests/unit/diff/test_goldens.lua`. It runs every row, asserts the row counts (69, 45, 5) and names the failing row's `source`. See it fail.

## Agent decisions

- Equality fixtures use a `kind` discriminator so one 45-row table can exercise trim equality and line-fragment ranges without inventing separate files.

## 2. LCS core

Scenarios: `diff: Changed lines become fragments`, `diff: Identical lines have no fragments`, `diff: Lines added after an empty line`, `diff: The engine loads without plugins`, `diff: Patience takes over when Myers exceeds its threshold`

- [ ] 2.1 Write these scenarios in `tests/unit/diff/test_lines.lua` and `test_limits.lua` (bare child), and see them fail
- [ ] 2.2 Add `lua/gleb/diff/engine/ranges.lua` (Range, change builders, iteration) and `lcs.lua`:
  - Port `Diff.buildChanges`, `Reindexer` and `MyersLCS` from IntelliJ, seeded from diffbandit's `myers_lcs.lua`.
  - Port `PatienceIntLCS` and `UniqueLCS` fresh.
  - Too-big is a returned status, not an `error()`.
- [ ] 2.3 Add `init.lua` with `compare_lines`, typed as in design Decision 2, and make the scenarios pass

## 3. ByLine and policies

Scenarios: `diff: Brace lines do not anchor a match`, `diff: Shifted indentation realigns exactly`, `diff: An inserted function slides to the empty line`, `diff: Trim and ignore policies differ on inner spaces`, `diff: Trailing whitespace line under trim`, `diff: Empty lines count unless chunks are ignored`, `diff: Carriage return is not whitespace`

- [ ] 3.1 Write the scenarios in `test_lines.lua` and `test_policies.lua`, and see them fail
- [ ] 3.2 Add `trim.lua`, `optimizer.lua` (`LineChunkOptimizer`), `by_line.lua` (`compareSmart`, `SmartLineChangeCorrector`, `correctChangesSecondStep`, `expandRanges`) and `policy.lua`:
  - Seed them from diffbandit's `smart_align.lua`.
  - Fix the whitespace set and the code-point counts.
  - Add `trim_whitespaces` and `ignore_whitespaces_chunks` (design Decision 3).
- [ ] 3.3 Make tasks 1 and 3 green: `make test FILE=tests/unit/diff/test_goldens.lua`, `test_lines.lua`, `test_policies.lua`

## 4. Limits, invariants and speed

Scenarios: `diff: A too big comparison falls back to xdiff`, `diff: A missed deadline falls back to xdiff`, `diff: A 5000-line file compares within budget`, `diff: Random texts keep IntelliJ's line invariants`

- [ ] 4.1 Write the scenarios in `test_limits.lua`, `test_perf.lua` (generator from design Decision 5, `H.load_factor()`) and `test_invariants.lua` (LCG, alphabets and invariants from Decision 6), and see them fail
- [ ] 4.2 Add the deadline context, clock checks and the `vim.text.diff` histogram fallback (design Decision 4)
- [ ] 4.3 Make the four files pass. If the perf bound fails, profile and optimise; never loosen the bound.

## 5. Attribution and docs

Scenarios: `diff: Ported files carry their attribution`

- [ ] 5.1 Write `tests/unit/diff/test_notice.lua` and see it fail
- [ ] 5.2 Add `lua/gleb/diff/engine/NOTICE` and `LICENSE-APACHE-2.0` (the verbatim Apache-2.0 text), and the header from design Decision 7 on every engine file and fixture table
- [ ] 5.3 Add a `diff/` row to the module map in `docs/architecture.md`: "IntelliJ-port diff engine (pure), viewer to follow", linked to the `diff` spec
- [ ] 5.4 Run `make check`
