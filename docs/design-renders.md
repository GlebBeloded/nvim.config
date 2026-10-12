# Design renders

A render is a fixed-width text picture of the Neovim screen. It is how we sketch, compare and approve UI
before writing code, and the approved one becomes the reference screenshot that the screen test asserts.

Rules for changes are in [`openspec/config.yaml`](../openspec/config.yaml) under `rules.design`. This page
explains how to write renders.

## Format

````markdown
**Current**: `100x1`, excerpt: statusline row, Normal mode, `lua/gleb/keymaps.lua`, lua_ls attached

```text
 NORMAL  ⎇ auto  + 3 ~ 1                                                             ✗ 0 ▲ 0  ◆ lua 
```

Highlights: `NORMAL` [lualine_a_normal] · `◆` [StatuslineLang_lua] · ` ◆ lua ` [StatuslineLangText]
````

- **Caption** first: label (Current, Proposed A, ...), `<columns>x<rows>`, mode, buffer and any state that
  matters (LSP attached, git changes, window focus).
- **Fence**: always ```` ```text ````. At most 100 columns. Every row is one screen row, and no row is
  wider than the stated width.
- **Real content**: use real file names, code, branch names and messages from this repo. No lorem ipsum
  and no `foo`/`bar`.
- **Whole screen or labelled excerpt**: an excerpt (for example only the statusline row) says so in the
  caption: `excerpt: last 2 rows`. A render that becomes a reference screenshot shows the exact rows the
  test captures.

## Characters

Only single-width characters. Emoji and Nerd Font glyphs (Private Use Area) have unreliable widths in
browsers and terminals, so use these stand-ins and keep the real glyph in the code and the screenshot:

| Stand-in | Meaning | Real glyph in config |
|---|---|---|
| `█` | cursor (the cell under the cursor) | n/a |
| `⎇` | git branch icon | lualine `branch.icon` |
| `+ ~ -` | diff added / modified / removed | lualine `diff.symbols` |
| `✗ ▲` | diagnostics error / warn | lualine `diagnostics.symbols` |
| `◆` | filetype logo | nvim-web-devicons |
| `(` `)` | rounded pill caps | `language.lua` `CAP_LEFT` / `CAP_RIGHT` |
| `▸ ▾` | tree expander collapsed / expanded | neo-tree `expander_*` |
| `■` | folder icon | neo-tree `folder_*` |
| `⊘` | Copilot failure glyph | `copilot.lua` `GLYPH` |
| `LL` | 🦙 (2 columns) | `ai_commit.lua` title |
| `⠹` | spinner frame | `lsp_progress.lua` `SPINNER` |

Add a row here when a render needs a new stand-in. Double-width glyphs get a 2-character stand-in so
columns stay aligned.

## Screen anatomy (this config)

| Row(s) | What | Option |
|---|---|---|
| first | bufferline tabline | `showtabline=2` (hidden on the alpha dashboard) |
| middle | windows | |
| last | one global lualine statusline | `laststatus=3` |
| none | no command-line row | `cmdheight=0` (messages overlay the last row) |

Inside a normal window: a 2-column sign column (`signcolumn=yes`), then a 4-column number column with
`number` + `relativenumber` (the cursor line shows the absolute number, the others the distance), then
text. Empty lines past the end of the buffer are blank (`fillchars=eob: `).

## Windows

- **Vertical split**: windows separated by a `│` column ([WinSeparator]).
- **Horizontal split**: a `─` row between windows. With `laststatus=3` there are no per-window
  statuslines.
- **Floating window**: draw it over the windows below, with its border. `border = "rounded"` is
  `╭─╮│╰─╯`, `"single"` is `┌─┐│└─┘`. Put the title in the top border and the footer in the bottom border,
  aligned as configured:

```text
╭──────────────── Commit Message ─────────────────╮
│feat(statusline): add copilot failure glyph█     │
╰───────────── <CR> ✓ │ i edit │ q ✗ ─────────────╯
```

- **Tab pages**: the bufferline row shows buffers, not tab pages. When a layout spans tabs, draw one render
  per tab and say which tab is current.

## Highlights

When color matters, add a `Highlights:` line or list under the render that maps text to highlight groups
with `[Name]` annotations:

```markdown
Highlights: ` NORMAL ` [lualine_a_normal] green bg, bold · `(` [StatuslineLangCapOk] green
```

Use the highlight group name the code sets, not a color name alone. If several cells on one row need
different groups and a list is ambiguous, add a mask block of the same width where each cell holds a
letter and the legend maps letters to groups (this mirrors the attribute part of a mini.test screenshot):

```text
 NORMAL  ⎇ auto                                                                    ✗ 0 ▲ 0 ( ◆ lua )
aaaaaaaabbbbbbbbccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccxxxxxxxxxkmlmmmmme
```

`a` [lualine_a_normal] · `b` [lualine_b_normal] · `c` [lualine_c_normal] · `x` [lualine_x_diagnostics_*] ·
`k` [StatuslineLangCapOk] · `l` [StatuslineLang_lua] · `m` [StatuslineLangText] · `e` [StatuslineLangEdge]

## Worked example: language chip variants

Context: `lua/gleb/statusline/language.lua` uses `STYLE = "logo_name"`, and the health of the LSP is only
shown by the left cap color. `CAP_LEFT` and `CAP_RIGHT` are empty strings in the code today (the Nerd Font
glyphs were lost), so the chip shows no health at all.

**Current**: `100x1`, excerpt: statusline row, Normal mode, `lua/gleb/keymaps.lua`, lua_ls attached

```text
 NORMAL  ⎇ auto  + 3 ~ 1                                                             ✗ 0 ▲ 0  ◆ lua 
```

Highlights: ` ◆ lua ` [StatuslineLangText] on `chip_bg`. Nothing shows that lua_ls is running.

**Proposed A**: restore the rounded caps (left cap colored by health)

```text
 NORMAL  ⎇ auto  + 3 ~ 1                                                           ✗ 0 ▲ 0 ( ◆ lua )
```

Highlights: `(` [StatuslineLangCapOk] green (or [StatuslineLangCapError] red) · `)` [StatuslineLangEdge]

**Proposed B**: health dot inside the chip (`STYLE = "dot_logo_name"`), no caps

```text
 NORMAL  ⎇ auto  + 3 ~ 1                                                           ✗ 0 ▲ 0  ● ◆ lua 
```

Highlights: `●` [StatuslineLspOk] green (or [StatuslineLspError] red)

Trade-off: A needs Nerd Font caps and only uses color; B works with any font and also reads in a
monochrome screenshot. If B is picked, its render becomes the text of the reference screenshot for
`statusline: statusline matches reference screenshot`.

## Flow

1. **Idea**: a finding, a wish, or an annoyance.
2. **Explore**: `/opsx:explore` with a Current render (from `make render` once available) and two or three
   Proposed renders labelled A/B/C.
3. **Pick**: the user (core UI or keymaps) or the agent (otherwise) picks one option and records why.
4. **Propose**: `/opsx:propose`. `design.md` carries the Current render and the chosen Proposed render; the
   spec delta adds or updates a reference-screenshot scenario that names it.
5. **Test**: the first task writes the screen test. It sets the same screen size and state as the caption,
   and the approved render is the expected text of the reference screenshot under `tests/screenshots/`.
   The test fails until the code matches.
6. **Build and verify**: implement until the screen test and `make check` pass, then compare
   `make render` output with the approved render.
