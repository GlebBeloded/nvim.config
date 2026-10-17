## 1. Extend the Go fixture
Scenarios: `references: gopls kinds classify a Go variable`
- [x] 1.1 Add `report/calls.go` and `report/calls_test.go` (contents as in Proposed K1's preview and design.md) to `gomod` in `tests/fixtures/build.sh`, plus the `Calls` manifest entries. Verify that `go build ./...` and `go vet ./...` pass and that the existing `Format` entries are unchanged.

## 2. Treesitter fallback
Scenarios: `references: Treesitter fallback classifies writes where a parser exists`, `references: Without kinds or a parser a usage is other`
- [x] 2.1 Write both scenarios in tests/unit/references/test_kind_ts.lua and see them fail
- [x] 2.2 Add `lua/gleb/references/kind_ts.lua`: pure write-target queries for go, lua and bash, applied only when `pcall(vim.treesitter.language.add, lang)` succeeds
- [x] 2.3 Run the file and see both pass

## 3. Server classification sources
Scenarios: `references: gopls kinds classify a Go variable`, `references: lua_ls kinds classify a Lua local`, `references: basedpyright kinds classify a Python variable`, `references: tsserver kinds classify a TypeScript variable`, `references: rust-analyzer kinds classify a Rust variable`
- [x] 3.1 Write the five scenarios in tests/integration/references/test_kind.lua (the gomod fixture, plus temporary Lua, Python, TypeScript and Cargo projects). A missing server is skipped with its reason. This file is the one per-language read/write suite: each case asserts the exact kind (write or read) of every usage line, not only counts. See them fail.
- [x] 3.2 Add `lua/gleb/references/kind.lua`:
  - the vtsls tsserver path;
  - per-file documentHighlight with range matching;
  - the fallback fill;
  - a cache keyed by uri and changedtick/mtime;
  - `CLASSIFY_TIMEOUT_MS = 3000`.
- [x] 3.3 Run the file and see all five pass or skip with a reason

## 4. Level, toggle and async view
Scenarios: `references: Function usages have no read/write level or hint`, `references: Read/write state persists across sessions`, `references: The read/write key comes from the keymap file`, `references: The view opens before classification finishes`, `references: Classification gives up after the timeout`
- [x] 4.1 Write the scenarios in tests/unit/references/test_tree.lua and tests/integration/references/test_kind_view.lua and see them fail
- [x] 4.2 Add:
  - the conditional read/write level and the row tags to `tree.lua`;
  - the `ReferencesWrite[Label]` and `ReferencesRead[Label]` groups to `icons.lua`;
  - the `references.toggle_read_write` action, with `w` in `settings/keymap.json`;
  - the conditional `Read/write` hint and the `· classifying` title state;
  - persistence;
  - a rebuild on classification that keeps the selection.
- [x] 4.3 Run both files and see every listed scenario pass

## 5. Screens and the real-key workflow
Scenarios: `references: Variable usages are grouped by write and read`, `references: w turns the level into row tags`
- [ ] 5.1 Add K1 and K2 to tests/screen/references/test_view.lua (the one screenshot suite for the view; no other screen file), using real glyphs in the screenshot text, and see them fail. Check that the V1–V4 references are unchanged.
- [ ] 5.2 Add an e2e case to tests/e2e/lsp/test_go_references.lua:
  1. a real `gr` on `Calls`;
  2. wait for classification;
  3. compare with K1;
  4. press `w` and compare with K2.
- [ ] 5.3 Make `make test-screen` and `make e2e` (sandbox VM) pass, then `make check`. Compare `make render` with `renders/kind_*.ansi`.

## Agent decisions

- Keep the `Calls` manifest locations explicit because comments and the failure string also contain the identifier, so the fixture's lexical helper would report non-symbol occurrences.
- Let the Treesitter fallback accept zero-based source positions and return an ordered kind list, matching the LSP data shape without mutating usages.
- Cache each server result below its URI/version by client and anchor range so classifications for different symbols cannot collide.
- Populate the lua_ls scenario from document highlights because that server omits assignment targets from its references response.
- Use the file-document glyph and the existing neutral usage colour for the uncommon `Usage` group because the approved renders only prescribe glyphs and colours for read and write.

## Stuck

- Task 5 is left red for the fix pass. The real-key e2e case passes, but both screen cases differ from the approved K1/K2 colour masks.
- Probe: the K1 `report` cell is Treesitter capture `@module.go` linked to `Fg`; `Count` is both `@variable.go` and `@function.go`, with `@function.go` linked to `TSFunction`.
- Attempt 1: remapped `@module.go` to `MiniPickNormal` in the preview window. That fixed `report`, then exposed `Count` as blue instead of the approved `@function.call` green and the selected K2 tag separator inheriting `CursorLine` background.
- Attempt 2: also remapped `@function.go` to `@function.call` and gave the kind-tag separator `MiniPickNormal`. `Count` matched, but its `(` remained `Fg` instead of `MiniPickNormal`, while the separator still combined with the `CursorLine` background.
- The preserved second production attempt is `/Users/hlebbeladzed/.archon/workspaces/GlebBeloded/nvim.config/artifacts/runs/f1714f29-d709-4cc9-a69c-c10182a4e30b/stuck-attempt.diff`; production edits were reverted and the red tests remain.
