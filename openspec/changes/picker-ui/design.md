## Context

See proposal.md (Why). A throwaway mini.pick prototype was tested in a real tmux pty (25 headless checks). It showed that right-aligned extmark labels, a dimmed secondary text, inline toggle refresh and an in-place item reload all work through `source.show`, `MiniPick.set_picker_items` and the `mappings` option. mini.pick refreshes itself on `VimResized` (`MiniPick.refresh`), and `window.config` may be a callable that is evaluated again on each refresh.

## Goals / Non-Goals

**Goals:** one frame and one row renderer, shared by every list menu. The look follows the approved render in `find-action/design.md` ("Proposed H1 (approved)"). It adapts to small windows.

**Non-Goals:** tabbed "search everywhere" and new code-search menus.

## Decisions

1. **Base: mini.pick, with our own `source.show`.**
   - A snacks-like look is achievable through highlight groups and extmarks.
   - The prototype tried a separate input float above the list (S1, S2). The user preferred the single window with the query in the top border.
   - Alternatives are in the proposal table.
2. **Frame.**
   - The top border text is `<title> › <query>`, through mini.pick's prompt in the window title.
   - Hint row:
     - It is the last buffer line of the list area, under a `├─┤` rule. The rule is drawn as virtual lines on the border columns; where the border cannot be joined, it falls back to an inner `─` rule.
     - Hints are right-aligned in [PmenuExtra] style.
     - Matches never scroll under the hint row: the hint row is reserved, and the item area is the window height minus 2.
3. **Row renderer** `picker.rows.render(buf, items, width, opts)`.
   - Each item has `{ text, secondary?, category?, glyph?, dim?, section? }`.
   - `secondary` gets a group dimmer than `category`.
   - A glyph sits before the category: `●` [PmenuKind] when on, `○` [PmenuExtra] when off.
   - Breakpoints are constants at the top of the file (rule 4.3): `FULL_MIN = 72`, `COMPACT_MIN = 48`, `SHORT_LINES = 15`.
4. **Grep and references** use mini.extra pickers wrapped by the frame, so they get the same hint row (`Open ↩ · Split ⌃S · Vsplit ⌃V`).
5. **`vim.ui.select`.** A single override in `lua/gleb/picker/select.lua` replaces `lua/gleb/select/`. Code actions keep the cursor-anchored small float, since the select spec pins a width that fits its content, but they use the same frame and rows.
6. **Dashboard.** Find file, recently used and find text move to shared sources. The project button is removed with project.nvim; adding a replacement project history is outside this change.

## Renders

**Current render**: `80x24`, Insert, excerpt: Telescope live-grep picker, query `picker`; the prompt and result titles interrupt borders, and the match counter occupies the bottom border

```text
╭────────────────────────── Live Grep ────────────────────────────╮
│> picker█                                                        │
├─────────────────────────── Results ─────────────────────────────┤
│lua/gleb/select/init.lua:6:vim.ui.select = function(items, opts,  │
│openspec/changes/picker-ui/proposal.md:9:one shared picker UI     │
╰─────────────────────────── 2 / 2 ───────────────────────────────╯
```

```text
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bpppppppffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb
bffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
```

Legend: `b` [TelescopeBorder] · `p` [TelescopePromptPrefix] · `f` [TelescopeNormal]

**Proposed render — wide live grep**: `80x24`, Insert, excerpt: shared picker, 72-column window, query `picker`; full row fields and hints

```text
╭ Live Grep › picker█───────────────────────────────────────────────────╮
│ config matches ────────────────────────────────────────────────────── │
│ vim.ui.select = function  lua/gleb/select/init.lua:6          Config │
│ one shared picker UI      openspec/changes/picker-ui/proposal.md:9 UI │
│ require("gleb.picker")    init.lua:17                        Startup │
├──────────────────────────────────────────────────────────────────────┤
│                                      Open ↩ · Split ⌃S · Vsplit ⌃V │
╰──────────────────────────────────────────────────────────────────────╯
```

```text
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb
bSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSb
bffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb
bffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
```

Legend: `b` [FloatBorder] · `f` [NormalFloat] · `S` [PmenuSel] · `x` [PmenuExtra] · title query caret [MiniPickPromptCaret]

**Proposed render — LSP references**: `80x24`, Normal, excerpt: shared picker, `lua/gleb/keymaps.lua`, current line included

```text
╭ References › █────────────────────────────────────────────────────────╮
│ current file ──────────────────────────────────────────────────────── │
│ local function lsp_references()  lua/gleb/keymaps.lua:156         Lua │
│ require("gleb.picker").lsp()     lua/gleb/keymaps.lua:157         Lua │
├──────────────────────────────────────────────────────────────────────┤
│                                      Open ↩ · Split ⌃S · Vsplit ⌃V │
╰──────────────────────────────────────────────────────────────────────╯
```

```text
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb
bSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSb
bffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
```

Legend: `b` [FloatBorder] · `f` [NormalFloat] · `S` [PmenuSel] · `x` [PmenuExtra] · title query caret [MiniPickPromptCaret]

**Proposed render — code action**: `80x24`, Normal, excerpt: cursor-anchored shared picker, code actions available

```text
╭ Code Actions › █────────────────────────────╮
│ Add missing import  source.organizeImports  │
│ Extract function    refactor.extract        │
├─────────────────────────────────────────────┤
│                  Choose ↩ · Cancel Esc     │
╰─────────────────────────────────────────────╯
```

```text
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSb
bffffffffffffffffffffffffffffffffffffffffffffffb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
```

Legend: `b` [FloatBorder] · `f` [NormalFloat] · `S` [PmenuSel] · `x` [PmenuExtra] · title query caret [MiniPickPromptCaret]

**Proposed render — compact**: `60x24`, Insert, excerpt: shared live-grep picker; categories hidden and hints reduced to keys

```text
╭ Live Grep › picker█───────────────────────────────────────╮
│ vim.ui.select = function  lua/gleb/select/init.lua:6      │
│ one shared picker UI      openspec/changes/picker-ui/...  │
├──────────────────────────────────────────────────────────┤
│                                            ↩ · ⌃S · ⌃V │
╰──────────────────────────────────────────────────────────╯
```

```text
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSb
bffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
```

Legend: `b` [FloatBorder] · `f` [NormalFloat] · `S` [PmenuSel] · `x` [PmenuExtra] · title query caret [MiniPickPromptCaret]

**Proposed render — narrow**: `40x24`, Insert, excerpt: shared live-grep picker; primary text only and no hint row

```text
╭ Live Grep › picker█───────────────────╮
│ vim.ui.select = function              │
│ one shared picker UI                  │
│ require("gleb.picker")                │
╰──────────────────────────────────────╯
```

```text
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSb
bffffffffffffffffffffffffffffffffffffffb
bffffffffffffffffffffffffffffffffffffffb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
```

Legend: `b` [FloatBorder] · `f` [NormalFloat] · `S` [PmenuSel] · title query caret [MiniPickPromptCaret]

The approved choice is the H1 single-window frame at all widths. The compact layouts remove metadata before reducing the result count, keeping search useful while honoring the user's “just the commands” choice on small windows.

## Risks / Trade-offs

- [mini.pick puts the prompt in the window title, and very long queries truncate] → the title is cut from the left, so the caret stays visible.
- [A joined `├┤` rule is not a native border feature] → the fallback inner rule is pinned by a screen test, so it cannot regress silently.
- [99 completion could retain a Telescope dependency] → configure 99's installed native completion source explicitly and remove Telescope from its plugin dependencies.

## Migration Plan

1. Land `picker/` alongside telescope.
2. Switch `gr`, `<A-F>`, `ui.select` and 99.
3. Remove telescope and project.nvim's extension in the same change.

Rollback: revert the change, which restores the telescope spec and wiring.
