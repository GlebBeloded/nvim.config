## Why

The Find Usages view groups usages by test scope and folder, but it can't yet tell writes from reads. The user asked for that grouping first: "conditional grouping on read/write references". LSP `textDocument/references` carries no usage kind, so the config has to derive it for every configured language.

Kind: feature
Depends: references-languages

## What Changes

- **Usage kinds:** every usage is classified as `write`, `read` or `other`.
  - The tree gains a conditional **read/write level** between test scope and folder: `Value write` (md-pencil, blue), `Value read` (md-eye, yellow), then `Usage`.
  - Labels use the paler shade of their icon colour.
- **The level is conditional.** It appears only when some usage is read or write. Functions, types and packages are reported as `Text` by servers, so their view stays exactly as in `references-view`, with no hint either.
- **Toggle:** `w` turns the level on or off. The hint row shows `● Read/write w`, and the state persists. With the level off, each row carries a right-aligned `✎ write` / `◎ read` tag.
- **Where the kinds come from, in order:**
  1. **vtsls (TS/JS):** one `typescript.tsserverRequest` `references` call (`isWriteAccess`).
  2. **Other clients with documentHighlight** (gopls, lua_ls, basedpyright, rust-analyzer): one request per file, matched to usages by range.
  3. **Treesitter fallback** for go, lua and bash, where parsers are installed: assignment, declaration and increment targets are `write`.
  4. Anything left is `other`.
- **Asynchronous:** the view opens immediately. The title shows `· classifying` until the kinds arrive (3 s timeout), and the rebuild keeps the selection.
- **Fixture:** `gomod` gains `report/calls.go` (`var Calls int`, written by `Count`) and `report/calls_test.go` (one write, two reads). The `Format` locations are unchanged.

## Capabilities

### New Capabilities
- none.

### Modified Capabilities
- `references`: new requirements for read/write grouping, the read/write toggle, usage-kind classification (one scenario per server, plus the fallback) and asynchronous classification. Existing requirements are unchanged, because the hint only appears when a symbol has read/write usages.

## Impact

- Code:
  - New: `lua/gleb/references/kind.lua` (sources) and `lua/gleb/references/kind_ts.lua` (pure fallback queries).
  - Changed: `tree.lua` (the conditional level and the tags), `view.lua` (the toggle, the hint and the title state), `icons.lua` (write and read groups), `settings/keymap.json` (`w`), `tests/fixtures/build.sh` (`gomod` additions and `Calls` manifest entries).
  - Added: `renders/*.ansi`.
- Tests:
  - **Unit:** fallback queries; level omitted without kinds; tags when the level is off.
  - **Integration:**
    - gopls kinds on `Calls`;
    - lua_ls, basedpyright, vtsls and rust-analyzer kinds on temporary snippets;
    - no kinds and no parser gives `other`;
    - toggle and persistence;
    - async open and timeout.
  - **Screen:** K1, K2, and V1 unchanged for `Format`.
  - **E2E:** real `gr` on `Calls`, then `w`, compared with K1 and K2.
- Plugins: none. Core keymaps: unchanged (`w` is view-local).
- `file-tree: gr keeps its global meaning in git status tree` still holds: this change leaves the global `gr` mapping and the git status tree's keys untouched.
- Out of scope:
  - import, call and declaration usage types;
  - filters by kind;
  - installing treesitter parsers for python, typescript, rust or hcl.

## Decision (user, 2026-10-16)

- "conditional grouping on read/write references, excluding tests"
- "I like yellow reads and blue writes. Also make the text … paler shades of that color programmatically."
- "It should work [for] all supported languages in config (where applicable), not only go."
- The approved renders are K1 and K2 in design.md.

## Decision (auditor, 2026-10-17, from the user's spec)

- Preview code cells keep the regular buffer's highlighting (main spec `references`, "Usage preview"): never remap capture groups in the preview. Regenerate the code cells of the K1/K2 masks (and their screenshots) from the real captures, e.g. `report` in `package report` is `@module`, `Count` in `func Count()` is `@function`; the frame, tree, levels, tags and hint stay as in renders/kind_*.ansi.
- A symbol whose usages are only calls (a function or method: documentSymbol kind Function/Method/Constructor at the definition, or the call-expression shape in the treesitter fallback) gets no read/write level or hint, even when its server reports documentHighlight Read for calls (lua_ls, basedpyright). test_languages.lua's expectations stay unchanged; V1–V4 stay unchanged.
- Each e2e case in tests/e2e/lsp/test_go_references.lua starts from the default view state (tests grouped, folders on, preview on, read/write on), whatever earlier cases on the shared stack persisted.
- Each case name appears in exactly one test file (trace rejects the duplicate between the e2e and screen files).

## Agent decisions

- The tsserver request comes first because vtsls' documentHighlight needs an open document. Per-file documentHighlight comes next because those servers are type-aware. Treesitter is only a fallback.
- The `Read/write` hint only appears when it can do something, so function-only views keep the `references-view` renders and screenshots.
