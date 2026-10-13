# Tasks

Glyphs are written as `\u{XXXX}` escapes in code and tests (design.md, Decision 1); tests may also use
`vim.fn.nr2char(0x…)` as `tests/integration/statusline/test_statusline.lua` does. Never a PUA literal.

## 0. Sync the spec deltas

Scenarios: none (prerequisite: `make trace` reads only `openspec/specs/`, so new case names are orphans until synced)

- [x] 0.1 Apply `specs/statusline/spec.md` (MODIFIED) to `openspec/specs/statusline/spec.md`, add `specs/file-tree/spec.md`'s "Tree icons" requirement to `openspec/specs/file-tree/spec.md`, and create `openspec/specs/lsp/spec.md` from `specs/lsp/spec.md` (Purpose + requirement, no `ADDED` header). `make trace` exits 0 and reports the new scenarios as missing.

## 1. Language chip caps

Scenarios: "statusline: chip has rounded caps", "statusline: chip shows error cap without LSP", "statusline: chip shows ok cap with running LSP"

Layer: unit (`tests/unit/statusline/test_language.lua`, bare child with nvim-web-devicons).

- [x] 1.1 Failing tests: add `T["statusline: chip has rounded caps"]` (filetype `lua`, no LSP: result starts with `%#StatuslineLangCapError#` .. `"\u{E0B6}"` and ends with `"\u{E0B4}"`); tighten "chip shows error cap without LSP" to assert the end is `%#StatuslineLangEdge#` .. `"\u{E0B4}"` and "chip shows ok cap with running LSP" to assert the start is `%#StatuslineLangCapOk#` .. `"\u{E0B6}"`. Run `make test FILE=tests/unit/statusline/test_language.lua` and confirm all three fail on the missing cap glyph.
- [x] 1.2 In `lua/gleb/statusline/language.lua` set `CAP_LEFT = "\u{E0B6}"`, `CAP_RIGHT = "\u{E0B4}"`. 1.1 passes; the other chip cases stay green.

## 2. Copilot failure glyph

Scenarios: "statusline: copilot glyph shown when disabled", "statusline: copilot glyph shown on warning", "statusline: copilot glyph hidden when healthy"

Layer: unit (`tests/unit/statusline/test_copilot.lua`, bare child; Copilot is disabled in full-config children).

- [x] 2.1 Failing tests: add a small typed helper `stub_copilot(opts)` that sets `package.loaded["copilot.client"]` (`is_disabled`, `startup_error`, `get`) and `package.loaded["copilot.status"]` (`data.status`) in the child. Cases: disabled → `component()` is `"\u{F4B8}"`; client present, status `Warning` → `"\u{F4B8}"`; enabled, no error, client, status `Normal` → `""`. Run `make test FILE=tests/unit/statusline/test_copilot.lua` and confirm the two shown cases fail (they return `""`); the healthy case passes and is a regression guard.
- [x] 2.2 In `lua/gleb/statusline/copilot.lua` set `GLYPH = "\u{F4B8}"`. 2.1 passes.

## 3. Statusline glyph names and screenshots

Scenarios: "statusline: diagnostics show error and warn counts", "statusline: diff hidden in narrow windows", "statusline: statusline matches reference screenshot", "statusline: insert mode accent matches reference screenshot"

Layers: integration (`tests/integration/statusline/test_statusline.lua`), screen (`tests/screen/statusline/test_statusline_screen.lua`).

- [x] 3.1 Failing test: add `T["statusline: diff hidden in narrow windows"]`: temp git repo with a committed file, modify it, `:edit` it, `columns = 80`, wait for gitsigns' `b:gitsigns_status_dict`, then assert the statusline row (`H.screen_rows(child, -1)`) contains none of `nr2char(0xF457)`, `nr2char(0xF459)`, `nr2char(0xF458)`. "diagnostics show error and warn counts" already asserts U+F057 / U+F071 + count and needs no edit. Both pass against the unchanged `lualine.lua` (the spec only renamed its glyphs), so show red by locally setting lualine's diff `cond` to always true (narrow case fails), then revert.
- [x] 3.2 Failing test: after 1.2 and 2.2, run `make test-screen CASE="statusline:"` and confirm both screenshot cases fail on the chip caps. Regenerate with `make screenshots`, review `git diff tests/screenshots`: the Normal row equals the Proposed statusline render in design.md (caps at columns 72 and 80), the attribute row shows two new groups at those cells. `make test-screen CASE="statusline:"` green.

## 4. LSP diagnostic signs

Scenarios: "lsp: diagnostic signs use Nerd Font glyphs", "lsp: error sign drawn in sign column"

Layer: integration (new `tests/integration/lsp/test_signs.lua`, real config).

- [x] 4.1 Failing tests: `T["lsp: diagnostic signs use Nerd Font glyphs"]` reads `vim.diagnostic.config().signs.text` after `child.wait_very_lazy()` and compares the four severities to `\u{F057}`, `\u{F071}`, `\u{F0335}`, `\u{F05A}`; `T["lsp: error sign drawn in sign column"]` edits a scratch `sample.lua`, `vim.diagnostic.set` one ERROR on line 1, redraws and asserts the first buffer row of `H.screen_rows` starts with U+F057. Confirm both fail (`M.setup` runs when the LSP config loads; if it is lazy, trigger it the way the config does, e.g. `:edit` a Lua file).
- [x] 4.2 In `lua/gleb/lsp/config/handlers.lua` set the sign texts to `"\u{F057}"` (ERROR), `"\u{F071}"` (WARN), `"\u{F0335}"` (HINT), `"\u{F05A}"` (INFO). 4.1 passes.

## 5. Neo-tree icons

Scenarios: "file-tree: Collapsed directory shows expander and folder icon", "file-tree: Expanded directory shows open expander and folder icon", "file-tree: Empty directory shows empty folder icon", "file-tree: Tree shows diagnostic glyph of a file", "file-tree: Conflicted file shows conflict symbol"

Layer: integration (new `tests/integration/file-tree/test_tree_icons.lua`; reuse fixture and wait helpers from `test_tree.lua` where they fit, by moving shared ones into a local module only if both files need them).

- [x] 5.1 Failing tests, one case per scenario, each in a temp fixture dir as cwd and a typed `tree_row(name)` helper that returns the neo-tree buffer line containing `name`:
  - collapsed: `:Neotree filesystem`, row of `docs` matches `\u{F460}.*\u{E5FF}.*docs`;
  - expanded: cursor on `docs`, `<cr>` in normal mode, row matches `\u{F47C}.*\u{E5FE}.*docs`;
  - empty: cursor on `empty`, `<cr>` twice, row contains `\u{F0256}` before `empty`;
  - diagnostics: `sample.lua` shown, `vim.diagnostic.set` one ERROR on its buffer, wait for the tree refresh, row of `sample.lua` contains U+F057 (depends on 4.2);
  - conflict: temp git repo, two branches editing `conflict.txt`, failed `git merge`, `:Neotree git_status`, row of `conflict.txt` contains U+E727.
  Run `make test FILE=tests/integration/file-tree/test_tree_icons.lua`; expander, folder and diagnostic cases fail. The conflict case passes already (neo-tree's default `conflict` is U+E727, design Context) and is a regression guard: show red by setting `conflict = "x"` locally.
  Note: the design's "conflict already draws U+E727" holds only when an ordinary change sorts before the conflict; neo-tree's porcelain v2 parser drops leading unmerged entries. The fixture also modifies `a.txt`; queued as `fix-neo-tree-leading-conflict`.
- [x] 5.2 In `lua/gleb/file_tree/init.lua`: `expander_collapsed = "\u{F460}"`, `expander_expanded = "\u{F47C}"`; `folder_closed = "\u{E5FF}"`, `folder_open = "\u{E5FE}"`, `folder_empty = "\u{F0256}"`; rename the dead `git_status.symbols.unmerged` key to `conflict = "\u{E727}"`; delete the `diagnostics.symbols` override so neo-tree uses `vim.diagnostic.config().signs.text` (design Decision 3). 5.1 passes; `tests/integration/file-tree/test_tree.lua` stays green.

## 6. Neo-tree reference screenshot

Scenarios: "file-tree: filesystem tree matches reference screenshot"

Layer: screen (new `tests/screen/file-tree/test_tree_screen.lua`).

- [x] 6.1 Failing test: the fixture from the scenario (`docs/workflow.md`, `empty/`, `lua/gleb/`, `init.lua`), `:Neotree filesystem`, `<cr>` on `docs`, `<cr>` twice on `empty`, then `H.expect_screenshot` of the tree rows below the root row (the root row holds the temp path). Write it before 5.2 is applied (or with 5.2 reverted locally) and with no reference file: confirm the first run creates a reference with blank icon cells, delete that reference.
- [x] 6.2 With 5.2 applied, `make screenshots CASE="file-tree:"` creates the reference; check its text equals rows 2–6 of the Proposed tree render in design.md (glyphs in place of the stand-ins). `make test-screen CASE="file-tree:"` green.

## 7. Verify

- [ ] 7.1 `grep -nE '= ""' lua/gleb/statusline/language.lua lua/gleb/statusline/copilot.lua lua/gleb/file_tree/init.lua lua/gleb/lsp/config/handlers.lua` lists only the intentionally empty fields (handlers `prefix` / `header`) (rule 9.5).
- [ ] 7.2 `make render CASE=lua-file` and `make render CASE=neo-tree` next to `make colorize FILE=openspec/changes/fix-empty-nerd-font-glyphs/design.md`: caps, Copilot glyph, signs and tree icons draw as glyphs, not tofu or blanks.
- [ ] 7.3 `make trace VERBOSE=1` lists every scenario of tasks 1–6 as tested; `make check` green.
