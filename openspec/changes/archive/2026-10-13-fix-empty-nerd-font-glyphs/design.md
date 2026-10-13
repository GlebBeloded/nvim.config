# Design

## Context

See proposal.md (Why). Root cause, checked byte by byte (`xxd`) and in git history:

- The fields are `""` in source, not a font or terminal problem. `statusline/language.lua` caps and
  `statusline/copilot.lua` `GLYPH` were already empty in the commit that added them (2aa1ce4), and
  `file_tree/init.lua` icons in ee34089. `lsp/config/handlers.lua` signs lost their glyphs in 038f1a8,
  when `sign_define` was replaced by `vim.diagnostic.config({ signs = { text = … } })`. Every commit
  that lost them wrote Private Use Area characters as literals, and the editing tool dropped them.
- Glyphs from history: LSP signs U+F057 / U+F071 / U+F834 / U+F05A (038f1a8^), nvim-tree diagnostics
  the same set, git conflict U+E727 and folders U+E5FF / U+E5FE (pre-ee34089).
- U+F834 is an old `nf-mdi-*` codepoint. Nerd Fonts v3 (installed: `*NerdFontPropo*` families exist only
  in v3) dropped the `F500–FD46` Material Design block and moved it to `F0001+`, so U+F834 draws tofu.
- neo-tree's `git_status.symbols` has no `unmerged` key (its keys are `added deleted modified renamed
  untracked ignored unstaged staged conflict`), so `unmerged = ""` is dead config and conflicts already
  draw neo-tree's default `conflict` U+E727.
- neo-tree's diagnostics component prefers `symbols[severity]` over `vim.diagnostic.config().signs.text`;
  with `symbols = { … = "" }` it draws a blank.

## Goals / Non-Goals

**Goals:** every icon slot listed in the proposal draws a glyph; glyphs are written so an editor that
strips PUA characters cannot erase them again; a test fails if any of them goes blank.

**Non-Goals:** replacing the literal glyphs in `lualine.lua` and `bufferline.lua` (they render; out of
scope per proposal), even though `bufferline.lua:29` `buffer_close_icon` (U+F655) is also a dropped
v2 `nf-mdi` codepoint. That one becomes its own queued change.

## Decisions

1. **Glyphs as `\u{XXXX}` escapes, not literals.** LuaJIT 2.1 supports `\u{…}` in strings. An escape is
   ASCII, survives any editor, and names the codepoint in review. Alternative: literals plus a
   `grep '= ""'` lint (rule 9.5) — rejected as the only guard because it catches the loss after the
   fact; the scenario tests below are the guard, the escapes are the prevention.
2. **Codepoints** (user decision: history first, neo-tree defaults otherwise, caps U+E0B6 / U+E0B4):

   | Field | Codepoint | Source |
   |---|---|---|
   | chip `CAP_LEFT` / `CAP_RIGHT` | U+E0B6 / U+E0B4 | decision |
   | Copilot `GLYPH` | U+F4B8 `nf-oct-copilot` | proposal candidate; Octicons, present in v3 |
   | LSP sign ERROR / WARN / INFO | U+F057 / U+F071 / U+F05A | 038f1a8^ |
   | LSP sign HINT | U+F0335 `nf-md-lightbulb` | v3 successor of U+F834 (`F500+n` → `F0001+n`) |
   | neo-tree expanders | U+F460 / U+F47C | neo-tree default |
   | neo-tree folders closed / open / empty | U+E5FF / U+E5FE / U+F0256 | history / default |
   | neo-tree git `conflict` | U+E727 | history (nvim-tree `unmerged`) |

3. **neo-tree diagnostics reuse the LSP sign glyphs:** remove the `diagnostics.symbols` override instead
   of filling it, so neo-tree reads `vim.diagnostic.config().signs.text` and highlights with
   `DiagnosticSign<Severity>`. One source of truth for the four severities. Alternative: copy the four
   escapes into neo-tree — rejected, two copies drift.
4. **Rename the dead `unmerged` key to `conflict`** with U+E727 (same glyph neo-tree draws today) so the
   config states what renders. Alternative: delete it — equally valid; renaming keeps intent visible.
5. **Guard = the scenarios.** Each restored field has a scenario asserting its exact codepoint (unit for
   `component()`, integration for `vim.diagnostic.config()` and neo-tree rows, screen for statusline and
   tree). Tests compare against `\u{…}` escapes, so they cannot be emptied by the same editor bug
   without the diff showing it.

## Renders

Stand-ins beyond `docs/workflow.md`: `⊙` Copilot glyph, `□` empty folder icon.

**Current**: `80x1`, excerpt: statusline row, Normal mode, `sample.lua` outside git, no LSP
(the `statusline matches reference screenshot` state)

```text
 NORMAL                                                          ✗ 0 ▲ 0  ◆ lua 
```

```text
aaaaaaaacccccccccccccccccccccccccccccccccccccccccccccccccccccccccxxxxwwwwmlmmmmm
```

Legend: `a` [lualine_a_normal] · `c` [lualine_c_normal] · `x` [lualine_x_diagnostics_error_normal] ·
`w` [lualine_x_diagnostics_warn_normal] · `l` [StatuslineLang_lua] · `m` [StatuslineLangText]

**Proposed**: `80x1`, same state. The chip gains its rounded caps; the left cap is red
([StatuslineLangCapError], no LSP), the right one is the chip color on the bar ([StatuslineLangEdge]).

```text
 NORMAL                                                        ✗ 0 ▲ 0 ( ◆ lua )
```

```text
aaaaaaaacccccccccccccccccccccccccccccccccccccccccccccccccccccccxxxxwwwwemlmmmmmg
```

Legend: `a` [lualine_a_normal] · `c` [lualine_c_normal] · `x` [lualine_x_diagnostics_error_normal] ·
`w` [lualine_x_diagnostics_warn_normal] · `e` [StatuslineLangCapError] · `l` [StatuslineLang_lua] ·
`m` [StatuslineLangText] · `g` [StatuslineLangEdge]

**Current**: Copilot loaded and disabled — identical to the Current row above (the glyph is `""`).

**Proposed**: `80x1`, excerpt: statusline row, Normal mode, same file, Copilot loaded and disabled
(`:Copilot disable`). `⊙` uses lualine's `color = { fg = palette.err }` (unchanged).

```text
 NORMAL                                                      ⊙ ✗ 0 ▲ 0 ( ◆ lua )
```

**Current**: `80x7`, excerpt: rows 2–7, neo-tree window (35 columns + border), `:Neotree filesystem`
in a fixture `nvim.config` with `docs/workflow.md`, `empty/`, `lua/gleb/`, `init.lua`; `<cr>` on
`docs`, twice on `empty` (captured with `make render`, `MONO=1`)

```text
  /private/var/folders/9c/yg1yg4td7┃
    docs                           ┃
   └ ◆ workflow.md                 ┃
    empty                          ┃
    lua                            ┃
   ◆ init.lua                      ┃
```

**Proposed**: same state, captured with the proposed neo-tree icons applied. Rows 2–6 (below the
temp-path root row) are the expected text of the `filesystem tree matches reference screenshot`
reference screenshot.

```text
 ■ /private/var/folders/9c/yg1yg4td┃
 ▾ ■ docs                          ┃
   └ ◆ workflow.md                 ┃
 ▾ □ empty                         ┃
 ▸ ■ lua                           ┃
   ◆ init.lua                      ┃
```

**Current**: `80x1`, excerpt: first buffer row, `sample.lua` with one error on line 1
(sign column 2 cells, then the relative number column)

```text
    1 local M = {}
```

**Proposed**: same state; the sign column draws the error sign in [DiagnosticSignError]. The neo-tree
row of a file with an error shows the same `✗`.

```text
✗   1 local M = {}
```

## Risks / Trade-offs

- [The terminal font lacks a codepoint] → all picks are in Nerd Fonts v3 sets (Octicons, Powerline
  Extra, Seti, Font Awesome, Material Design `F0001+`); verify with `make render` after
  implementing.
- [Statusline reference screenshots change] → regenerate with `make screenshots`; the new expected row
  is the Proposed render above.
- [The empty-directory row keeps neo-tree's expanded expander `▾`] → neo-tree behaviour, not specified
  beyond the folder glyph.
- [neo-tree diagnostics reads only the first diagnostic namespace's `signs` when `signs` is a function]
  → our `signs` is a table, so not affected.
