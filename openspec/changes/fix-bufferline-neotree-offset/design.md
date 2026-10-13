# Design

## Context

Root cause: bufferline draws an offset only for a window whose buffer filetype equals the offset's
`filetype`. `lua/gleb/bufferline.lua` names `NvimTree`, a plugin this config no longer uses; the tree is
neo-tree (filetype `neo-tree`, left, width 35, see the `file-tree` spec). The offset never matches, so
the tabs start at column 1 above the tree.

bufferline sizes a matched offset as window width + `padding`. With the tree at 35 columns and the
window separator `┃` in column 36, `padding = 1` puts the first tab at column 37, the editor's first
column. The offset text is taken from the tree window's highlight unless `highlight` is set.

## Goals / Non-Goals

**Goals:**
- Tabs align with the editor window while the tree is open; unchanged when it is closed.

**Non-Goals:**
- Offsets for other side panels (Outline, dap-ui) and a git_status tree on the right: none open on the
  left at full height today.

## Decisions

- **Match on `neo-tree`, keep `text = ""` and `padding = 1`** (user decision 2026-10-12: empty label, no
  separator, default highlight). Alternatives: a `"Files"` or cwd label (repeats the tree's own root
  line), a `│` separator (the window separator already draws one below).
- **Only the filetype changes**; no custom code, bufferline's built-in offsets do the work.

### Renders

The screen tests take a screenshot of row 1 (tabline) only; the rest is context.

**Current**: `100x12`, Normal mode, focus in neo-tree, `:Neotree filesystem` opened next to an empty
buffer in this checkout (`make render CASE=neo-tree MONO=1 COLUMNS=100 LINES=12`)

```text
       [No Name]                                                                                    
█■ ~/.archon/workspaces/GlebBeloded┃  1                                                             
  ▸ ■ .archon                      ┃                                                                
  ▸ ■ .claude                      ┃                                                                
  ▸ ■ .pi                          ┃                                                                
  ▸ ■ .tests                     ◌ ┃                                                                
  ▸ ■ docs                         ┃                                                                
  ▸ ■ lua                          ┃                                                                
  ▸ ■ openspec                     ┃                                                                
  ▸ ■ ops                          ┃                                                                
  ▸ ■ terminal                     ┃                                                                
 NORMAL  ⎇ loop/fix-bufferline-neotree-offset                                   ✗ 0 ▲ 0  ◆ neo-tree 
```

**Proposed** (picked; the only option after the user's decision): same state, tabs offset by 36 columns

```text
                                           [No Name]                                                
█■ ~/.archon/workspaces/GlebBeloded┃  1                                                             
  ▸ ■ .archon                      ┃                                                                
  ▸ ■ .claude                      ┃                                                                
  ▸ ■ .pi                          ┃                                                                
  ▸ ■ .tests                     ◌ ┃                                                                
  ▸ ■ docs                         ┃                                                                
  ▸ ■ lua                          ┃                                                                
  ▸ ■ openspec                     ┃                                                                
  ▸ ■ ops                          ┃                                                                
  ▸ ■ terminal                     ┃                                                                
 NORMAL  ⎇ loop/fix-bufferline-neotree-offset                                   ✗ 0 ▲ 0  ◆ neo-tree 
```

[BufferLineFill] fills the tabline right of the tab · [BufferLineBufferSelected] the `[No Name]` tab ·
the offset (columns 1-36) uses the tree window's highlight ([NeoTreeNormal] / [NeoTreeNormalNC],
gruvbox-material `bg0`), so it reads as part of the tree column.

With the tree closed the tabline row is the Current row 1: `[No Name]` tab from column 1.

## Risks / Trade-offs

- [The offset's color follows neo-tree's `winhighlight`; transparency mode clears `NeoTree*` groups] →
  accepted; the user chose the default highlight. The screen test asserts layout, not color.
- [Tree root path makes the full screen depend on the checkout path] → the screenshot covers only the
  tabline row, which holds no path.
