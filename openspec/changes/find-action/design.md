## Context

See proposal.md (Why). The design was explored in three rounds, with colored renders and two live prototypes: mini.pick and snacks, each tested headless and in a real tmux pty. The user's picks are recorded in proposal.md (Decision). The registry, keymap file and action context come from `action-registry`. The frame, rows and breakpoints come from `picker-ui`.

## Goals / Non-Goals

**Goals:** find any action by name, see its shortcut, run it in the context it was opened from, and assign a shortcut without leaving the editor.

**Non-Goals:**
- Tabs or Search Everywhere.
- Removing or resetting shortcuts (a later shortcuts screen).
- Abbreviations.

## Decisions

1. **Picked layout: Proposed H1 (approved) below.** It was chosen over:
   - A (tabs and a footer on the border);
   - B (VS Code dropdown);
   - C (Ivy panel with a detail pane);
   - S1/S2 (a separate input float);
   - H2 (a background band behind the hints);
   - H3 (a blank row with accented keys).

   The user preferred the single window, with the query in the border and the S1 row styling, plus a joined rule for the hints.
2. **Labels.** The physical label comes from a table derived from the shortcuts spec (`<M-g>` → `⌘G`). Keys that arrive the same way from two physical keys, such as `<C-H>` from both Cmd+H and Ctrl+H, show the Cmd form. A key with no physical label shows Vim notation (`gd`).
3. **Recently used** is stored in `stdpath("state")/find_action_recent.json`, holding the last 20 action ids. It is per machine and not versioned.
4. **Assign float.**
   - It is a second picker-frame float over the palette: the palette stays visible behind it and focus returns to it afterwards.
   - Its own key loop replaces `vim.fn.confirm`, because the prototype showed that `confirm` leaves a "Press ENTER" prompt that blocks the palette from reopening.
   - Buttons are chosen with `←/→/Tab` plus `<CR>`, or with their first letter (R/K/C).
5. **Run in context.** The palette closes, `ctx.win` is made current, any visual selection is restored, and then the action runs. Toggles run inside `nvim_win_call(ctx.win, …)` while the palette stays open.
   - The prototype bug this fixes: toggles and the LSP-availability check read the palette window instead of the window the palette was opened from.
6. **Show hidden** is the open key pressed again inside the palette. The query is kept. Hidden rows are dimmed below `More results ───`.
7. **Narrow layouts** follow the `picker` breakpoints. Their renders (72, 60 and 40 columns) are added in the design step, from the same content as H1.

## Renders

**Current**: `100x30`, Normal, `sample.lua` (`make render CASE=lua-file`). Today Cmd+Shift+A reaches Neovim unmapped and nothing opens.

```text
▎      sample.lua                                                                                  
  1   local M = {}                                                                                  
    1                                                                                               
    2 function M.hello()                                                                            
    3 ▏ return "world"                                                                              
    4 end                                                                                           
    5                                                                                               
    6 return M                                                                                      
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
 NORMAL                                                                             0  0   lua 
```

**Proposed H1 (approved)**: `100x30`, Normal, `keymaps.lua`, lua_ls; one mini.pick window, no query, Open Differ selected; `wrap` on, `spell` off; stand-ins: `█` prompt caret, `●` switch on, `○` switch off; hints right-aligned, no counter

```text
▎    ◆ keymaps.lua                                                                                  
    7 end                                                                                           
    6                                                                                               
    5 -- Neo-tree (Cmd+E/G via Alt escape sequences from Alacritty)                                 
    4 map("n", "<A-e>", function()                                                                  
    3 ▏ sm╭ Find Action › █──────────────────────────────────────────────────────────────╮          
    2 end,│ recently used ────────────────────────────────────────────────────────────── │          
    1 -- <│ Open Differ  ⌘G                                                   Git | Diff │          
  143 map(│ Soft Wrap                                                    ● View | Editor │          
    1 map(│ Spell Check                                                  ○ View | Editor │          
    2 ▏ sm│ Find in Files...  ⌘⇧F                                            Edit | Find │          
    3 end,│ other actions ────────────────────────────────────────────────────────────── │          
    4     │ Find Action...  ⌘⇧A                                                     Help │          
    5 -- T│ Find File...  ⌘O                                                    Navigate │          
    6 map(│ Find in Buffer  /                                                Edit | Find │          
    7     │ Toggle File Tree  ⌘E                                     View | Tool Windows │          
    8 -- C│ Toggle Git Status Tree  ⌘⇧G                              View | Tool Windows │          
    9 map(│ Open Diffview                                                     Git | Diff │          
   10 map(│ Blame Line                                                               Git │          
   11     │ Copy Permalink                                                           Git │          
   12 -- L├──────────────────────────────────────────────────────────────────────────────┤          
   13 loca│                                                  Assign ⌥↩ · Show hidden ⌘⇧A │          
   14 ▏ re╰──────────────────────────────────────────────────────────────────────────────╯          
   15 end                                                                                           
   16                                                                                               
   17 local function clear_long_gr_maps()                                                           
   18 ▏ for _, mapping in ipairs(vim.api.nvim_get_keymap("n")) do                                   
   19 ▏ ▏ if mapping.lhs ~= "gr" and vim.startswith(mapping.lhs, "gr") then                         
   20 ▏ ▏ ▏ vim.keymap.del("n", mapping.lhs)                                                        
 NORMAL  ⎇ auto                                                                    ✗ 0 ▲ 0  ● ◆ lua 
```

```text
IBBBBBBBBBBBBBBBBBBBBBBFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
..nnn...............................................................................................
..nnn...............................................................................................
..nnn.ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc.................................
..nnn.ppp.sss..sssssss..............................................................................
..nnn.i...bPPPPPPPPPPPPPPPCbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
..nnn.....bfXXXXXXXXXXXXXfbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbfb..........
..nnn.ccccbSSSSSSSSSSSSSSEESSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSEEEEEEEEEESb..........
..rrr.ppp.bffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffKfXXXXXXXXXXXXXfb..........
..nnn.ppp.bffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffXfXXXXXXXXXXXXXfb..........
..nnn.i...bfffffffffffffffffffbbbffffffffffffffffffffffffffffffffffffffffffffXXXXXXXXXXXfb..........
..nnn.....bfXXXXXXXXXXXXXfbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbfb..........
..nnn.....bfffffffffffffffffbbbfffffffffffffffffffffffffffffffffffffffffffffffffffffXXXXfb..........
..nnn.ccccbfffffffffffffffbbffffffffffffffffffffffffffffffffffffffffffffffffffffXXXXXXXXfb..........
..nnn.ppp.bfffffffffffffffffbffffffffffffffffffffffffffffffffffffffffffffffffXXXXXXXXXXXfb..........
..nnn.....bfffffffffffffffffffbbfffffffffffffffffffffffffffffffffffffXXXXXXXXXXXXXXXXXXXfb..........
..nnn.ccccbfffffffffffffffffffffffffbbbffffffffffffffffffffffffffffffXXXXXXXXXXXXXXXXXXXfb..........
..nnn.ppp.bfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffXXXXXXXXXXfb..........
..nnn.ppp.bffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffXXXfb..........
..nnn.....bffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffXXXfb..........
..nnn.ccccbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
..nnn.....bffffffffffffffffffffffffffffffffffffffffffffffffffXXXXXXXXXXXXXXXXXXXXXXXXXXXfb..........
..nnn.i...bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........
..nnn...............................................................................................
..nnn...............................................................................................
..nnn...............................................................................................
..nnn.i..................................................sss........................................
..nnn.i.i...................ssss.................................ssss...............................
..nnn.i.i.i................sss......................................................................
aaaaaaaakkkkkkkkhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhheeeewwwhvovuvvvvv
```

Legend: `n` [LineNr] · `r` [CursorLineNr] · `c` [Comment] · `s` [@string] · `p` [@function.call] ·
`i` [IblIndent] · `I` [BufferLineIndicatorSelected] · `B` [BufferLineBufferSelected] ·
`F` [BufferLineFill] · `a` [lualine_a_normal] · `k` [lualine_b_normal] · `h` [lualine_c_normal] ·
`e` [lualine_x_diagnostics_error_normal] · `w` [lualine_x_diagnostics_warn_normal] ·
`o` [StatuslineLspOk] · `u` [StatuslineLang_lua] · `v` [StatuslineLangText] · `f` [NormalFloat] ·
`b` [FloatBorder] · `S` [PmenuSel] · `E` [PmenuExtraSel] · `X` [PmenuExtra] · `K` [PmenuKind] ·
`P` [MiniPickPromptPrefix] · `C` [MiniPickPromptCaret]

Trade-off: the rule joins the border, so the hints read as the window's footer panel, but it costs
a row and is the same grey line as the section rules.

**Proposed F1: assign float**: `100x30`, Normal, `keymaps.lua`, lua_ls; ⌥↩ on Open Diffview, ⌘G

```text
▎    ◆ keymaps.lua                                                                                  
    7 end                                                                                           
    6                                                                                               
    5 -- Neo-tree (Cmd+E/G via Alt escape sequences from Alacritty)                                 
    4 map("╭────────────────────────────────────────────────────────────────────────────╮           
    3 ▏ sma│  All   Actions   Files   Symbols   Text                       Tab next tab │           
    2 end, ├────────────────────────────────────────────────────────────────────────────┤           
    1 -- <A│ > diff█                                                            2 of 39 │           
  143 map("├────────────────────────────────────────────────────────────────────────────┤           
    1 map("│ Open Differ  ⌘G                                                 Git | Diff │           
    2 ▏ sma│ Open Diffview                                                   Git | Diff │           
    3 end, │ + 17 Ex a╭─ Assign Shortcut · Open Diffview ────────────────────╮ ...      │           
    4      ╰──────────│  Press keys, Enter to save, Esc to cancel            │More ⌘⇧A ─╯           
    5 -- Telescope    │                                                      │                      
    6 map("n", "<A-F>"│  ╭────────────────────────────────────────────────╮  │                      
    7                 │  │  ⌘G █                                          │  │                      
    8 -- Code actions │  ╰────────────────────────────────────────────────╯  │                      
    9 map("n", "<C-CR>│                                                      │                      
   10 map("x", "<C-CR>│  Already assigned to:                                │                      
   11                 │  Open Differ                             Git | Diff  │                      
   12 -- LSP navigatio│                                                      │                      
   13 local function l│  [ Remove other ]  [ Keep both ]  [ Cancel ]         │                      
   14 ▏ require("teles╰──────────────────────────────── Tab next   ↩ choose ─╯rue })                
   15 end                                                                                           
   16                                                                                               
   17 local function clear_long_gr_maps()                                                           
   18 ▏ for _, mapping in ipairs(vim.api.nvim_get_keymap("n")) do                                   
   19 ▏ ▏ if mapping.lhs ~= "gr" and vim.startswith(mapping.lhs, "gr") then                         
   20 ▏ ▏ ▏ vim.keymap.del("n", mapping.lhs)                                                        
 NORMAL  ⎇ auto                                                                    ✗ 0 ▲ 0  ● ◆ lua 
```

```text
IBBBBBBBBBBBBBBBBBBBBBBFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
..nnn...............................................................................................
..nnn...............................................................................................
..nnn.ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc.................................
..nnn.ppp.sbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb...........
..nnn.i....bfffffffTTTTTTTTTfffffffffffffffffffffffffffffffffffffffffffffffXXXXXXXXXXXXfb...........
..nnn......bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb...........
..nnn.cccccbfKffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffXXXXXXXfb...........
..rrr.ppp.sbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb...........
..nnn.ppp.sbffffffMMMMffffXXfffffffffffffffffffffffffffffffffffffffffffffffffXXXXXXXXXXfb...........
..nnn.i....bSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSEEEEEEEEEESb...........
..nnn......bfXXXXXXXXXbbtttttttttttttttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbXXXXffffffb...........
..nnn......bbbbbbbbbbbbffXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXffffffffffffbzzzzzzzzzbb...........
..nnn.cccccccccccc....bffffffffffffffffffffffffffffffffffffffffffffffffffffffb......................
..nnn.ppp.sss..sssssssbffbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbffb......................
..nnn.................bffbfTTTTfffffffffffffffffffffffffffffffffffffffffffbffb......................
..nnn.ccccccccccccccc.bffbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbffb......................
..nnn.ppp.sss..sssssssbffffffffffffffffffffffffffffffffffffffffffffffffffffffb......................
..nnn.ppp.sss..sssssssbffXXXXXXXXXXXXXXXXXXXXffffffffffffffffffffffffffffffffb......................
..nnn.................bddddddddddddddddddddddddddddddddddddddddddddddddddddddb......................
..nnn.ccccccccccccccccbffffffffffffffffffffffffffffffffffffffffffffffffffffffb......................
..nnn.................bffSSSSSSSSSSSSSSSSffLLLLLLLLLLLLLffLLLLLLLLLLfffffffffb......................
..nnn.i.........ssssssbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbzzzzzzzzzzzzzzzzzzzzzbb......................
..nnn...............................................................................................
..nnn...............................................................................................
..nnn...............................................................................................
..nnn.i..................................................sss........................................
..nnn.i.i...................ssss.................................ssss...............................
..nnn.i.i.i................sss......................................................................
aaaaaaaakkkkkkkkhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhheeeewwwhvovuvvvvv
```

Legend: `n` [LineNr] · `r` [CursorLineNr] · `c` [Comment] · `s` [@string] · `p` [@function.call] ·
`i` [IblIndent] · `I` [BufferLineIndicatorSelected] · `B` [BufferLineBufferSelected] ·
`F` [BufferLineFill] · `a` [lualine_a_normal] · `k` [lualine_b_normal] · `h` [lualine_c_normal] ·
`e` [lualine_x_diagnostics_error_normal] · `w` [lualine_x_diagnostics_warn_normal] ·
`o` [StatuslineLspOk] · `u` [StatuslineLang_lua] · `v` [StatuslineLangText] · `f` [NormalFloat] ·
`b` [FloatBorder] · `t` [FloatTitle] · `z` [FloatFooter] · `S` [PmenuSel] · `E` [PmenuExtraSel] ·
`X` [PmenuExtra] · `K` [PmenuKind] · `T` [TabLineSel] · `L` [TabLine] · `M` [Search] ·
`d` [DiffDelete]

Trade-off: a modal float makes capture unambiguous (every key goes to it) and the buttons name the
outcome, but it covers the list, so the conflicting row is restated inside the float.

**Proposed F2: assign float, no conflict**: `100x30`, Normal, `keymaps.lua`, lua_ls; ⌘⇧D

```text
▎    ◆ keymaps.lua                                                                                  
    7 end                                                                                           
    6                                                                                               
    5 -- Neo-tree (Cmd+E/G via Alt escape sequences from Alacritty)                                 
    4 map("╭────────────────────────────────────────────────────────────────────────────╮           
    3 ▏ sma│  All   Actions   Files   Symbols   Text                       Tab next tab │           
    2 end, ├────────────────────────────────────────────────────────────────────────────┤           
    1 -- <A│ > diff█                                                            2 of 39 │           
  143 map("├────────────────────────────────────────────────────────────────────────────┤           
    1 map("│ Open Differ  ⌘G                                                 Git | Diff │           
    2 ▏ sma│ Open Diffview                                                   Git | Diff │           
    3 end, │ + 17 Ex a╭─ Assign Shortcut · Open Diffview ────────────────────╮ ...      │           
    4      ╰──────────│  Press keys, Enter to save, Esc to cancel            │More ⌘⇧A ─╯           
    5 -- Telescope    │                                                      │                      
    6 map("n", "<A-F>"│  ╭────────────────────────────────────────────────╮  │                      
    7                 │  │  ⌘⇧D █                                         │  │                      
    8 -- Code actions │  ╰────────────────────────────────────────────────╯  │                      
    9 map("n", "<C-CR>│                                                      │                      
   10 map("x", "<C-CR>│  No conflicts                                        │                      
   11                 │                                                      │                      
   12 -- LSP navigatio│  [ Save ]  [ Cancel ]                                │                      
   13 local function l╰──────────────────────────────── Tab next   ↩ choose ─╯                      
   14 ▏ require("telescope.builtin").lsp_references({ include_current_line = true })                
   15 end                                                                                           
   16                                                                                               
   17 local function clear_long_gr_maps()                                                           
   18 ▏ for _, mapping in ipairs(vim.api.nvim_get_keymap("n")) do                                   
   19 ▏ ▏ if mapping.lhs ~= "gr" and vim.startswith(mapping.lhs, "gr") then                         
   20 ▏ ▏ ▏ vim.keymap.del("n", mapping.lhs)                                                        
 NORMAL  ⎇ auto                                                                    ✗ 0 ▲ 0  ● ◆ lua 
```

```text
IBBBBBBBBBBBBBBBBBBBBBBFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
..nnn...............................................................................................
..nnn...............................................................................................
..nnn.ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc.................................
..nnn.ppp.sbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb...........
..nnn.i....bfffffffTTTTTTTTTfffffffffffffffffffffffffffffffffffffffffffffffXXXXXXXXXXXXfb...........
..nnn......bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb...........
..nnn.cccccbfKffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffXXXXXXXfb...........
..rrr.ppp.sbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb...........
..nnn.ppp.sbffffffMMMMffffXXfffffffffffffffffffffffffffffffffffffffffffffffffXXXXXXXXXXfb...........
..nnn.i....bSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSEEEEEEEEEESb...........
..nnn......bfXXXXXXXXXbbtttttttttttttttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbXXXXffffffb...........
..nnn......bbbbbbbbbbbbffXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXffffffffffffbzzzzzzzzzbb...........
..nnn.cccccccccccc....bffffffffffffffffffffffffffffffffffffffffffffffffffffffb......................
..nnn.ppp.sss..sssssssbffbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbffb......................
..nnn.................bffbfTTTTTffffffffffffffffffffffffffffffffffffffffffbffb......................
..nnn.ccccccccccccccc.bffbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbffb......................
..nnn.ppp.sss..sssssssbffffffffffffffffffffffffffffffffffffffffffffffffffffffb......................
..nnn.ppp.sss..sssssssbDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDb......................
..nnn.................bffffffffffffffffffffffffffffffffffffffffffffffffffffffb......................
..nnn.ccccccccccccccccbffSSSSSSSSffLLLLLLLLLLffffffffffffffffffffffffffffffffb......................
..nnn.................bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbzzzzzzzzzzzzzzzzzzzzzbb......................
..nnn.i.........sssssssssssssssssss.................................................................
..nnn...............................................................................................
..nnn...............................................................................................
..nnn...............................................................................................
..nnn.i..................................................sss........................................
..nnn.i.i...................ssss.................................ssss...............................
..nnn.i.i.i................sss......................................................................
aaaaaaaakkkkkkkkhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhheeeewwwhvovuvvvvv
```

Legend: `n` [LineNr] · `r` [CursorLineNr] · `c` [Comment] · `s` [@string] · `p` [@function.call] ·
`i` [IblIndent] · `I` [BufferLineIndicatorSelected] · `B` [BufferLineBufferSelected] ·
`F` [BufferLineFill] · `a` [lualine_a_normal] · `k` [lualine_b_normal] · `h` [lualine_c_normal] ·
`e` [lualine_x_diagnostics_error_normal] · `w` [lualine_x_diagnostics_warn_normal] ·
`o` [StatuslineLspOk] · `u` [StatuslineLang_lua] · `v` [StatuslineLangText] · `f` [NormalFloat] ·
`b` [FloatBorder] · `t` [FloatTitle] · `z` [FloatFooter] · `S` [PmenuSel] · `E` [PmenuExtraSel] ·
`X` [PmenuExtra] · `K` [PmenuKind] · `T` [TabLineSel] · `L` [TabLine] · `M` [Search] ·
`D` [DiffAdd]

Trade-off: the free shortcut saves with one ↩ and no extra question, but the same float costs a
step more than A2's inline capture when there is nothing to resolve.

## Risks / Trade-offs

- [Cmd+Shift+A delivery through Alacritty and zellij is unverified] → the shortcut-table row is checked by chain, then stack, then e2e, before any palette test depends on it.
- [An action's effect differs when run from the palette] → a generated integration case per action compares palette-run against key-press in the same fixture.
- [Visual drift between renders and the real UI] → every approved render is a reference screenshot, and e2e compares zellij dumps with it.
- [The F1/F2 backgrounds still show the round-1 palette, with the tab row and the border footer] → the assign float is approved as drawn, and its reference screenshot is drawn over the H1 palette in the design step.
