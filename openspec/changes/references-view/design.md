## Context

See proposal.md (Why). Research (2026-10-16):
- **No plugin to adopt.** glance.nvim (928★), lspsaga finder (3.8k★), trouble.nvim v3 (6.9k★, no push for a year), and the snacks, fzf-lua, mini.extra and telescope reference pickers. None groups by test scope or folder, and none classifies read/write. glance.nvim's peek layout comes closest but can't be extended with these groupings.
- **mini.pick doesn't fit.** Its preview replaces the list instead of sitting beside it, and its rows are flat (`lua/gleb/picker/rows.lua` has no indent or fold). The view therefore owns its windows. It reuses the picker highlight groups (`lua/gleb/picker/frame.lua:31-53`) and the rule 8.9 frame.
- **Preview without side effects.**
  - `bufload` fires `BufRead`/`FileType`, and `FileType` runs `vim.lsp.enable`, which attaches servers. It also lists the buffer and creates a swap file.
  - A scratch buffer (`nvim_create_buf(false, true)`) is skipped by `vim.lsp.enable`'s FileType callback.
  - Highlighting comes from `vim.treesitter.start(buf, lang)`, with the language from `vim.filetype.match`. When no parser is installed, it falls back to `vim.bo[buf].syntax = ft`. The config installs parsers only for bash, go, gomod, json, lua, markdown, vim, vimdoc and yaml (`lua/gleb/treesitter.lua`), so Python, TS, Rust and Terraform previews use Vim syntax, just as their regular buffers do.

## Goals / Non-Goals

**Goals:** a two-pane Find Usages view for every references-capable server in the config, with toggled grouping by test scope and folder, GoLand-like icons, and a preview highlighted exactly like a regular buffer, with no side effects.

**Non-Goals:** read/write (`references-usage-kind`), code rows, a function level, results history, typing a filter.

## Decisions

1. **Modules** (`lua/gleb/references/`):
   - `init.lua`: entry point and the `references.*` actions.
   - `request.lua`: async references.
     - Only clients that advertise `referencesProvider` are asked.
     - Results are de-duplicated by uri and range, and the declaration is excluded.
   - `tree.lua`: pure. It builds nodes from `{ path, lnum, col, test }` and `{ tests = "grouped"|"hidden"|"mixed", folders = bool }`. One folder node holds each full relative directory. Node ids are stable, and counts are kept.
   - `icons.lua`: glyphs and highlight groups.
     - Groups: `ReferencesProduction`, `ReferencesTest`, `ReferencesFolder`, and one `…Label` per icon.
     - A file label group is created per devicon highlight (`ReferencesFileLabel<DevIconGroup>`).
     - Label foregrounds are computed as `mix(icon, fg1, LABEL_PALENESS = 0.7)` from the gruvbox-material palette helpers, and recomputed on `ColorScheme`.
   - `view.lua`: the windows, rendering, the hint row, and keys. The tree buffer has filetype `gleb-references`, so the registry binds `ft` actions.
   - `preview.lua`: the scratch buffer, highlighting, and text from the loaded buffer or a bounded `readfile`.
   - `state.lua`: persists grouping to `stdpath("state")/references.json`.
2. **Geometry.**
   - Wide layout: width = `columns - 4`, height = `lines - 2`, and the tree takes 45% of the inner width.
   - Without the preview (below 80 columns, or after `P`): width = max(widest tree row, hint) + 4, height = rows + 4, both capped by the editor and centred.
   - `VimResized` recomputes the geometry.
3. **Hint row.**
   - Wide: `Tests: <mode> t · ●/○ Folders f · Preview P · Open ↩`.
   - Without the preview: Preview and Open are dropped.
   - Key labels come from `settings/keymap.json`.
4. **Selection.**
   - On open, the first usage row is selected.
   - A rebuild keeps the same usage (matched by uri, line and column), or else the nearest row.
   - Fold state is kept per node id.
5. **Opening a usage:** close the view, return to the origin window, `:edit` the file, and set the cursor. This behaves like `vim.lsp.util.show_document` with `focus = true`.

## Renders

**Current**: `80x24`, Normal, excerpt: the shared references picker approved in `picker-ui` (archive `2026-10-14-picker-ui/design.md`). It is a flat list with no grouping and no preview.

```text
╭ References › █────────────────────────────────────────────────────────╮
│ current file ──────────────────────────────────────────────────────── │
│ local function lsp_references()  lua/gleb/keymaps.lua:156         Lua │
│ require("gleb.picker").lsp()     lua/gleb/keymaps.lua:157         Lua │
├──────────────────────────────────────────────────────────────────────┤
│                                      Open ↩ · Split ⌃S · Vsplit ⌃V │
╰──────────────────────────────────────────────────────────────────────╯
```

Stand-ins for Nerd Font glyphs in the renders:

| Stand-in | Real glyph |
|---|---|
| `▣` | oct-rocket U+F427 (Production) |
| `▲` | oct-beaker U+F499 (Test) |
| `□` | md-folder_outline U+F0256 (folder) |
| `◆` | the file's devicon |

The `References*` groups are created by this change, so `make colorize` shows them as Normal until it lands. The approved real-glyph, real-colour versions are in `renders/view_v1_default.ansi` … `renders/view_v4_narrow.ansi`. View them with `command cat` (`bat` and `less` mangle private-use glyphs).

**Proposed V1 — default grouping**: `100x30`, Normal, `billing/invoice.go`, gopls attached, `gr` on `Format` (line 16); tests grouped, folders on; first usage selected; preview with the file's own treesitter highlighting, usage line number [CursorLineNr], usages of `Format` [Search].

```text
▎ invoice.go                                                                                        
  ╭ Usages of Format · 4 ────────────────────┬───────────────────────────────────────────────────╮  
  │ ▾ ▣ Production  3                        │ billing/invoice.go:16                             │  
  │   ▾ □ billing  2                         │   5  // Invoice is a list of line amounts in cent…│  
  │       ◆ invoice.go:16                    │   6  type Invoice struct {                        │  
  │       ◆ invoice.go:23                    │   7      Lines []int                              │  
  │   ▾ □ report  1                          │   8  }                                            │  
  │       ◆ summary.go:7                     │   9                                               │  
  │ ▾ ▲ Test  1                              │  10  // Due renders the sum of the lines.         │  
  │   ▾ □ internal/money  1                  │  11  func (i Invoice) Due() string {              │  
  │       ◆ money_test.go:6                  │  12      total := 0                               │  
  │                                          │  13      for _, cents := range i.Lines {          │  
  │                                          │  14          total += cents                       │  
  │                                          │  15      }                                        │  
  │                                          │  16      return money.Format(total)               │  
  │                                          │  17  }                                            │  
  │                                          │  18                                               │  
  │                                          │  19  // Rendered renders every line.              │  
  │                                          │  20  func (i Invoice) Rendered() []string {       │  
  │                                          │  21      lines := []string{}                      │  
  │                                          │  22      for _, cents := range i.Lines {          │  
  │                                          │  23          lines = append(lines, money.Format(c…│  
  │                                          │  24      }                                        │  
  │                                          │  25      return lines                             │  
  │                                          │  26  }                                            │  
  │                                          │                                                   │  
  ├──────────────────────────────────────────┴───────────────────────────────────────────────────┤  
  │                                          Tests: grouped t · ● Folders f · Preview P · Open ↩ │  
  ╰──────────────────────────────────────────────────────────────────────────────────────────────╯  
 NORMAL  ⎇ main                                                                                  go 
```

```text
....................................................................................................
..bttttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bfffPfppppppppppffsffffffffffffffffffffffffbfsssssssssssssssssssssfffffffffffffffffffffffffffffb..
..bfffffDfdddddddffsfffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmb..
..bcccccccGcggggggggggcccccccccccccccccccccccbfsssffkkkkfffffffffkkkkkkffffffffffffffffffffffffffb..
..bfffffffGfggggggggggsssffffffffffffffffffffbfsssffffffffffffffTTTffffffffffffffffffffffffffffffb..
..bfffffDfddddddffsffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffGfggggggggggssfffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffEfeeeeffsffffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmfffffffffb..
..bfffffDfddddddddddddddffsffffffffffffffffffbfsssffkkkkfffffffffffffFFFfffTTTTTTffffffffffffffffb..
..bfffffffGfgggggggggggggssffffffffffffffffffbfsssfffffffffffffffnfffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkfffffffffffffkkkkkffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfrrrffffffkkkkkkfffffffhhhhhhffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffkkkkfffffffffffffFFFFFFFFfffffTTTTTTfffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffTTTTTTffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkfffffffffffffkkkkkffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffffffffffffffFFFFFFffffffffffffffhhhhhhfffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkkkkfffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bffffffffffffffffffffffffffffffffffffffffffxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
....................................................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `r` [CursorLineNr] · `h` [Search] · `x` [PickerHint] · `o` [PickerToggleOn] · `k` [@keyword] · `T` [@type.builtin] · `F` [@function.call] · `q` [@string] · `m` [@comment] · `n` [@number] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconGo] · `g` [ReferencesFileLabelDevIconGo] · `W` [ReferencesWrite] · `w` [ReferencesWriteLabel] · `Y` [ReferencesRead] · `y` [ReferencesReadLabel]

**Proposed V2 — tests hidden**: `100x30`, as V1 after `t` (grouped → hidden).

```text
▎ invoice.go                                                                                        
  ╭ Usages of Format · 3 ────────────────────┬───────────────────────────────────────────────────╮  
  │ ▾ ▣ Production  3                        │ billing/invoice.go:16                             │  
  │   ▾ □ billing  2                         │   5  // Invoice is a list of line amounts in cent…│  
  │       ◆ invoice.go:16                    │   6  type Invoice struct {                        │  
  │       ◆ invoice.go:23                    │   7      Lines []int                              │  
  │   ▾ □ report  1                          │   8  }                                            │  
  │       ◆ summary.go:7                     │   9                                               │  
  │                                          │  10  // Due renders the sum of the lines.         │  
  │                                          │  11  func (i Invoice) Due() string {              │  
  │                                          │  12      total := 0                               │  
  │                                          │  13      for _, cents := range i.Lines {          │  
  │                                          │  14          total += cents                       │  
  │                                          │  15      }                                        │  
  │                                          │  16      return money.Format(total)               │  
  │                                          │  17  }                                            │  
  │                                          │  18                                               │  
  │                                          │  19  // Rendered renders every line.              │  
  │                                          │  20  func (i Invoice) Rendered() []string {       │  
  │                                          │  21      lines := []string{}                      │  
  │                                          │  22      for _, cents := range i.Lines {          │  
  │                                          │  23          lines = append(lines, money.Format(c…│  
  │                                          │  24      }                                        │  
  │                                          │  25      return lines                             │  
  │                                          │  26  }                                            │  
  │                                          │                                                   │  
  ├──────────────────────────────────────────┴───────────────────────────────────────────────────┤  
  │                                           Tests: hidden t · ● Folders f · Preview P · Open ↩ │  
  ╰──────────────────────────────────────────────────────────────────────────────────────────────╯  
 NORMAL  ⎇ main                                                                                  go 
```

```text
....................................................................................................
..bttttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bfffPfppppppppppffsffffffffffffffffffffffffbfsssssssssssssssssssssfffffffffffffffffffffffffffffb..
..bfffffDfdddddddffsfffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmb..
..bcccccccGcggggggggggcccccccccccccccccccccccbfsssffkkkkfffffffffkkkkkkffffffffffffffffffffffffffb..
..bfffffffGfggggggggggsssffffffffffffffffffffbfsssffffffffffffffTTTffffffffffffffffffffffffffffffb..
..bfffffDfddddddffsffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffGfggggggggggssfffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmfffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffkkkkfffffffffffffFFFfffTTTTTTffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffnfffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkfffffffffffffkkkkkffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfrrrffffffkkkkkkfffffffhhhhhhffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffkkkkfffffffffffffFFFFFFFFfffffTTTTTTfffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffTTTTTTffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkfffffffffffffkkkkkffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffffffffffffffFFFFFFffffffffffffffhhhhhhfffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkkkkfffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bfffffffffffffffffffffffffffffffffffffffffffxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
....................................................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `r` [CursorLineNr] · `h` [Search] · `x` [PickerHint] · `o` [PickerToggleOn] · `k` [@keyword] · `T` [@type.builtin] · `F` [@function.call] · `q` [@string] · `m` [@comment] · `n` [@number] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconGo] · `g` [ReferencesFileLabelDevIconGo] · `W` [ReferencesWrite] · `w` [ReferencesWriteLabel] · `Y` [ReferencesRead] · `y` [ReferencesReadLabel]

**Proposed V3 — tests mixed, folders off**: `100x30`, as V1 after `t` `t` and `f`; rows are paths relative to the working directory, test usages carry a Test tag.

```text
▎ invoice.go                                                                                        
  ╭ Usages of Format · 4 ────────────────────┬───────────────────────────────────────────────────╮  
  │ ◆ billing/invoice.go:16                  │ billing/invoice.go:16                             │  
  │ ◆ billing/invoice.go:23                  │   5  // Invoice is a list of line amounts in cent…│  
  │ ◆ internal/money/money_test.go:6  ▲ test │   6  type Invoice struct {                        │  
  │ ◆ report/summary.go:7                    │   7      Lines []int                              │  
  │                                          │   8  }                                            │  
  │                                          │   9                                               │  
  │                                          │  10  // Due renders the sum of the lines.         │  
  │                                          │  11  func (i Invoice) Due() string {              │  
  │                                          │  12      total := 0                               │  
  │                                          │  13      for _, cents := range i.Lines {          │  
  │                                          │  14          total += cents                       │  
  │                                          │  15      }                                        │  
  │                                          │  16      return money.Format(total)               │  
  │                                          │  17  }                                            │  
  │                                          │  18                                               │  
  │                                          │  19  // Rendered renders every line.              │  
  │                                          │  20  func (i Invoice) Rendered() []string {       │  
  │                                          │  21      lines := []string{}                      │  
  │                                          │  22      for _, cents := range i.Lines {          │  
  │                                          │  23          lines = append(lines, money.Format(c…│  
  │                                          │  24      }                                        │  
  │                                          │  25      return lines                             │  
  │                                          │  26  }                                            │  
  │                                          │                                                   │  
  ├──────────────────────────────────────────┴───────────────────────────────────────────────────┤  
  │                                            Tests: mixed t · ○ Folders f · Preview P · Open ↩ │  
  ╰──────────────────────────────────────────────────────────────────────────────────────────────╯  
 NORMAL  ⎇ main                                                                                  go 
```

```text
....................................................................................................
..bttttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bcGcggggggggggggggggggcccccccccccccccccccccbfsssssssssssssssssssssfffffffffffffffffffffffffffffb..
..bfGfggggggggggggggggggsssffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmb..
..bfGfggggggggggggggggggggggggggggssffEfeeeefbfsssffkkkkfffffffffkkkkkkffffffffffffffffffffffffffb..
..bfGfgggggggggggggggggssffffffffffffffffffffbfsssffffffffffffffTTTffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmfffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffkkkkfffffffffffffFFFfffTTTTTTffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffnfffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkfffffffffffffkkkkkffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfrrrffffffkkkkkkfffffffhhhhhhffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffkkkkfffffffffffffFFFFFFFFfffffTTTTTTfffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffTTTTTTffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkfffffffffffffkkkkkffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffffffffffffffFFFFFFffffffffffffffhhhhhhfffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkkkkfffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bffffffffffffffffffffffffffffffffffffffffffffxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
....................................................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `r` [CursorLineNr] · `h` [Search] · `x` [PickerHint] · `o` [PickerToggleOn] · `k` [@keyword] · `T` [@type.builtin] · `F` [@function.call] · `q` [@string] · `m` [@comment] · `n` [@number] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconGo] · `g` [ReferencesFileLabelDevIconGo] · `W` [ReferencesWrite] · `w` [ReferencesWriteLabel] · `Y` [ReferencesRead] · `y` [ReferencesReadLabel]

**Proposed V4 — no preview**: `70x24`, as V1 in a 70-column editor; the preview is hidden, the window shrinks to its content and stays centred, the hint row drops Preview and Open.

```text
▎ invoice.go                                                          
   1 package billing                                                  
   2                                                                  
   3 import "example.com/fixture/internal/money"                      
   4                                                                  
   5 // Invoice is╭ Usages of Format · 4 ──────────╮                  
   6 type Invoice │ ▾ ▣ Production  3              │                  
   7     Lines []i│   ▾ □ billing  2               │                  
   8 }            │       ◆ invoice.go:16          │                  
   9              │       ◆ invoice.go:23          │                  
  10 // Due render│   ▾ □ report  1                │                  
  11 func (i Invoi│       ◆ summary.go:7           │                  
  12     total := │ ▾ ▲ Test  1                    │                  
  13     for _, ce│   ▾ □ internal/money  1        │                  
  14         total│       ◆ money_test.go:6        │                  
  15     }        ├────────────────────────────────┤                  
  16     return mo│ Tests: grouped t · ● Folders f │                  
  17 }            ╰────────────────────────────────╯                  
  18                                                                  
  19 // Rendered renders every line.                                  
  20 func (i Invoice) Rendered() []string {                           
  21     lines := []string{}                                          
  22     for _, cents := range i.Lines {                              
 NORMAL  ⎇ main                                                    go 
```

```text
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
..................bttttttttttttttttttttttbbbbbbbbbbb..................
..................bfffPfppppppppppffsffffffffffffffb..................
..................bfffffDfdddddddffsfffffffffffffffb..................
..................bcccccccGcggggggggggcccccccccccccb..................
..................bfffffffGfggggggggggsssffffffffffb..................
..................bfffffDfddddddffsffffffffffffffffb..................
..................bfffffffGfggggggggggssfffffffffffb..................
..................bfffEfeeeeffsffffffffffffffffffffb..................
..................bfffffDfddddddddddddddffsffffffffb..................
..................bfffffffGfgggggggggggggssffffffffb..................
..................bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..................
..................bfxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxb..................
..................bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..................
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
......................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `r` [CursorLineNr] · `h` [Search] · `x` [PickerHint] · `o` [PickerToggleOn] · `k` [@keyword] · `T` [@type.builtin] · `F` [@function.call] · `q` [@string] · `m` [@comment] · `n` [@number] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconGo] · `g` [ReferencesFileLabelDevIconGo] · `W` [ReferencesWrite] · `w` [ReferencesWriteLabel] · `Y` [ReferencesRead] · `y` [ReferencesReadLabel]

## Risks / Trade-offs

- [Several clients answer for one buffer (vtsls + eslint, basedpyright + ruff)] → only clients with `referencesProvider` are asked, and results are de-duplicated by uri and range.
- [Thousands of usages] → the tree is built once per change. Above 500 usages (`MAX_UNFOLDED`), folder groups start folded.
- [Large files in the preview] → `readfile` reads a bounded window, and highlighting is skipped above 1 MB, as in mini.pick.
- [Nerd Font missing] → the glyphs are the user's terminal font (Hack Nerd Font Mono). Tests assert highlight groups and text, not font rendering.
