## Why
Several Nerd Font glyph strings are empty in the source (bytes checked with `xxd`), probably because an earlier edit stripped Private Use Area characters, so the UI draws nothing where an icon belongs:
- `lua/gleb/statusline/language.lua:24-25` `CAP_LEFT` / `CAP_RIGHT`: the chip has no rounded caps and, with `STYLE = "logo_name"`, no LSP health at all.
- `lua/gleb/statusline/copilot.lua:6` `GLYPH` (empty since 2aa1ce4): the Copilot failure indicator never shows anything.
- `lua/gleb/file_tree/init.lua:120-121` (expanders), `:124-126` (folder icons), `:135` (git `unmerged`), `:144-147` (diagnostic symbols).
- `lua/gleb/lsp/config/handlers.lua:12-15` diagnostic sign texts (the glyphs existed until 038f1a8: U+F057, U+F071, U+F834, U+F05A).

The specs copy the loss: `openspec/specs/statusline/spec.md` asserts `""` in "copilot glyph shown when disabled" and "copilot glyph shown on warning", and its requirement text shows empty backticks for the branch icon, the diff symbols and the Copilot glyph even though `lualine.lua:14,23,34` still contain them.

Kind: bug

## What Changes
- Restore a Nerd Font glyph in every empty icon field listed above.
- Fix the statusline spec: the Copilot "shown" scenarios assert the glyph, not `""`; the requirement text names the real glyphs (by codepoint, so they survive editors that strip PUA characters).
- Add a guard so this cannot regress silently, e.g. a unit test that the listed icon fields are non-empty (convention rule 9.5).
- Proposal only: the work-queue (queue-spec) writes the spec delta and design. The design needs Current and Proposed renders (see `docs/workflow.md`, Design renders) for the statusline chip, the Copilot glyph and the neo-tree window.
- Open question for the user: which glyph (codepoint) for each field. Candidates: chip caps U+E0B6 / U+E0B4 (half circles); Copilot U+F4B8 or U+EC1E; neo-tree defaults (expanders U+F460 / U+F47C, folders U+E5FF / U+E5FE / U+F114, unmerged U+E727, diagnostics U+F05A etc.); LSP signs from 038f1a8.
- Dropped as already fine: `lua/gleb/debugging/gutter.lua:5-8` DAP sign texts are not empty (each is a 3-byte PUA glyph). `lsp/config/handlers.lua:7,26-27` (`prefix`, float `header`) and the lualine separators are intentionally empty.

## Capabilities
### Modified Capabilities
- `statusline`: "Copilot failure indicator" and "Statusline visual style" (Copilot glyph, rounded chip caps), plus the glyphs named in "Global statusline layout".
- `file-tree`: neo-tree icon configuration (expanders, folders, git unmerged, diagnostics); queue-spec decides whether this is specified as a reference screenshot.

## Impact
- Code: `lua/gleb/statusline/language.lua`, `lua/gleb/statusline/copilot.lua`, `lua/gleb/file_tree/init.lua`, `lua/gleb/lsp/config/handlers.lua`; tests in `tests/unit/statusline/test_copilot.lua`; reference screenshots in `tests/screenshots/` are regenerated (`make screenshots`) once the renders are approved.
- Plugins: none added, removed or upgraded
- Core keymaps: unchanged
- Out of scope: changing colors or layout beyond restoring the glyphs; the chip `STYLE`; icons that already render (lualine branch/diff/diagnostics, bufferline, DAP signs).
