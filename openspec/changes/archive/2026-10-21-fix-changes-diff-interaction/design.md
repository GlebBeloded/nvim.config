## Context

git-changes-tabs gave the Changes panel a Branch tab whose diffs compare `git show <merge-base>` with
`git show HEAD` (commit rows: `<commit>^` with `<commit>`), both as line lists, under a purple `committed` layer of
the owned diff view. The diff view's `show` (the panel's entry point) never places the cursor, unlike `open`
(`diff.open_file`). proposal.md `## Evidence` has the repro: purple rows, cursor on line 1 of a fold, a nameless
`nofile` right pane that refuses edits (E21), and the first `<C-l>` landing in the read-only left pane.

## Goals / Non-Goals

**Goals:**

- Every diff the panel shows uses the Local tab's colours.
- Every shown diff starts with its cursor on the first change, focus unchanged.
- Local and Branch right panes are the working-tree file buffer (edit, `:w`, LSP, live re-diff); commit diffs are
  read-only, navigable, highlighted and one `gf` away from the editor.

**Non-Goals:**

- Changing the Branch tab's rows, stats, header or panel colours; changing the Comments tab.
- Hunk revert or staging against the merge-base; editing commits.
- New panel keys or global keymaps.

## Decisions

1. **Branch file diffs are merge-base → working tree** (lead decision). IntelliJ's "compare with branch" diff edits
   the current-version side; `docs/architecture.md` (Key decisions, diff) already says the right pane is the real
   file buffer. The Branch spec is built like the Local one (`bufadd`/`bufload` of the path, loaded buffers recorded
   in `loaded_buffers` so `q` unloads them unmodified; deleted or binary files keep read-only lines) with the
   merge-base text on the left. Its right winbar is `Your version`. The Branch rows and stats stay merge-base → HEAD:
   a file changed only locally is the Local tab's.
2. **`committed` means history, not colour.** The field stays on the spec: no include checkboxes, not actionable
   (no stage, no revert: the left is not `HEAD`), but drawing uses the kind groups; `DiffViewCommitted*` and their
   `ColorScheme` definitions are deleted. Purple stays in the panel (tab pill, header, `ChangesCommittedFile`) and
   in `git-committed-signs`' gutter signs, which mark committed work in normal buffers.
3. **No checkbox column content for committed specs.** The right gutter keeps its width; the checkbox cell is
   blank, as the Current render already shows for committed diffs (the Proposed renders blank the `☐` the patched
   capture drew).
4. **Cursor placement in `show`.** After the windows exist, `show` puts the right cursor on
   `fragments[1].start2 + 1` (clamped to the line count, the line just below a gap for a pure deletion, as
   `navigate` does) and syncs the left through `layout.transfer_line`, then restores the current window. No
   centring: `]c` does not centre either, and closed folds keep the first change near the top.
5. **Read-only right side gets syntax.** The scratch right buffer of a commit diff starts Tree-sitter for
   `spec.filetype`, as `windows.left_buffer` does for the left; no LSP attaches to it (no file name on disk).
6. **`diff.jump_to_source` on `gf`.** One action for every view: close the view (panel-owned views through the
   panel, so its `diff_view` state is cleared) and edit `spec.path` in the window that held the right side (or the
   origin window for a tab-owned view), cursor on the right line under the cursor or the line transferred from the
   left, clamped. diffview.nvim's `gf` (`diffview.goto_file_edit`) is the precedent in this config.
7. **Entering the panes stays native.** `<C-l>`/`<C-h>` (`window.move_right`/`window.move_left`) and `<C-w>l`
   already move panel → left → right; with the cursor already on the first change the right pane is useful on
   arrival. A dedicated "focus diff" panel key would be a keymap decision for the user.

## Risks / Trade-offs

- A Branch diff now loads the file buffer (LSP attach, ufo) like a Local diff; stepping through many Branch files
  costs what the Local tab costs. Buffers loaded only by the panel are unloaded on close as today.
- Uncommitted edits appear inside the Branch diff, so it no longer equals the pull request diff exactly; the
  Branch rows still list the committed files and the Local tab still separates uncommitted work.
- Editing the right pane re-diffs on the debounce; a `:w` refreshes the panel, which keeps the view by its
  `branch:` key (no flicker).

## Renders

Real captures of the full config on the `billing-branch` fixture in a private tmux, 100x30 (scratch
`diffint/capture.lua`, the `changes-branch` render case). Current is `make render CASE=changes-branch`
unchanged. The Proposed captures ran the same case with `load_branch_diff` patched to this design (working-tree
buffer on the right, `Your version`, no `committed` colour, no index) and Tree-sitter started on the read-only
right side; the checkbox glyph the patched capture still drew is blanked (Decision 3). Text, line numbers and
hashes are real. Stand-ins: `◆` devicons and the PR and commit glyphs, `▾ ▸` expanders, `□` open folder. Colour
copies: `renders/<name>.ansi` (`command cat`). Screen tests compare columns 37-100 (the editor area) with these
renders and columns 1-36 with git-changes-tabs' approved panel renders, which do not change.

**Current — Branch diff in purple**: `100x30`, Normal, `internal/billing/invoice.go` of the `billing-branch` fixture (branch `feat/tax`, PR #482), second `changes.review`; panel focused on `invoice.go`, the editor area shows the read-only `4ccefde · main` → `e325463 · HEAD` diff, its right pane a nameless scratch buffer without syntax; captured with `make render CASE=changes-branch COLUMNS=100 LINES=30` (`renders/current_branch_diff.ansi`)

```text
                                     ◆ invoice.go                                                   
  Local 3   Branch 4   Comments 0  ┃ 4ccefde · main                           e325463 · HEAD        
 ◆ #482 feat/tax → main            ┃~~ 4 unchanged lines ~~~~ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 3 commits · merge-base 4ccefde    ┃                             5        5                         
                                   ┃   "example.com/billing/i    6        6     "example.com/billing
 ▾ □ internal/billing 4            ┃ )                           7        7   )                     
   ▾ ◆ invoice.go           +11 -2 ┃                             8        8                         
       ◆ invoice_test.go    +20 -1 ┃ // Invoice is a list of  »  9        9   // Invoice is a list o
   ▾ ◆ tax.go               +41 -0 ┃ type Invoice struct {      10       10   type Invoice struct { 
       ◆ tax_test.go        +33 -0 ┃   ID    string             11       11     ID    string        
                                   ┃   Lines []int              12       12     Lines []int         
                                   ┃   Tax   Rate               13       13     Tax   Rate          
                                   ┃ }                          14       14   }                     
                                   ┃                            15       15                         
                                   ┃ // Total sums the lines    16       16   // Total sums the line
                                   ┃ func (i Invoice) Total()   17       17   func (i Invoice) Total
                                   ┃   total := 0             » 18       18     var total int       
                                   ┃   for _, cents := range    19       19     for _, cents := rang
                                   ┃     total += cents         20       20       total += cents    
                                   ┃   }                        21       21     }                   
                                   ┃╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱ »╱╱╱╱      22     if i.Tax == nil {   
                                   ┃╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱  ╱╱╱╱      23       return total      
                                   ┃╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱  ╱╱╱╱      24     }                   
                                   ┃   return i.Tax.Apply(tot   22       25     return i.Tax.Apply(t
                                   ┃ }                          23       26   }                     
                                   ┃                            24       27                         
                                   ┃ // Due renders the total   25       28   // Due renders the tot
───────────────────────────────────┃ func (i Invoice) Due() s   26       29   func (i Invoice) Due()
           Commits c · Next tab ⌘G ┃   return fmt.Sprintf("du   27       30     return fmt.Sprintf("
 NORMAL  ⎇ feat/tax  ◆ #482                                               ◆ 0 ◆ 0 ◆ ◆ gleb-changes ◆
```

```text
....................................abbaaaaaaaaaaaaccccccccccccccccccccccccccccccccccccccccccccccccc
.ddddddddd.eeeeeeeeee.dddddddddddd.fggggggggggggggggggggggggg.gggggggggggggggggggggggggggggggggggggg
.hhhhhhiiiiiiiiiiiiiiii............fjjkkkkkkkkkkkkkkkkkkkjjjjljjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj
.iiiiiiiiiiiiiiiiiiiiiiiiiiiiii....f.........................l.kkkk.....kkkk........................
...................................f...mmmmmmmmmmmmmmmmmmmmmml.kkkk.....kkkk........................
.i.n..................i............f.........................l.kkkk.....kkkk........................
ooodooooooooooooooooooooooooooooooof.........................l.kkkk.....kkkk........................
.......b.ppppppppppppppp....qqq.rr.fjssssssssssssssssssssssssltuuuujjjjjuuuuuuvvvvvvvvvvvvvvvvvvvvvv
...i.b.pppppp...............qqq.rr.f.wwww.xxxxxxx.wwwwww.....l.kkkk.....kkkk........................
.......b.ppppppppppp........qqq.rr.f...xx....yyyyyy..........l.kkkk.....kkkk........................
...................................f...xxxxx...yyy...........l.kkkk.....kkkk........................
...................................f...xxx...yyyy............l.kkkk.....kkkk........................
...................................f.........................l.kkkk.....kkkk........................
...................................f.........................l.kkkk.....kkkk........................
...................................f.ssssssssssssssssssssssssl.kkkk.....kkkk........................
...................................f.wwww....yyyyyyy..zzzzz..l.kkkk.....kkkk........................
...................................fjvvvvvvvvAAAAvvvvvvvvvvvvltuuuujjjjjuuuuuuvvAAAAvvvvvvAAAvvvvvvv
...................................f...www.xm.xxxxx.ww.wwwww.l.kkkk.....kkkk........................
...................................f.....xxxxx.ww.xxxxx......l.kkkk.....kkkk........................
...................................f.........................l.kkkk.....kkkk........................
...................................flllllllllllllllllllllllllltlllljjjjjuuuuuuvvvvvvvvvvvvvvvvvvvvvv
...................................fllllllllllllllllllllllllll.lllljjjjjuuuuuuvvvvvvvvvvvvvvvvvvvvvv
...................................fllllllllllllllllllllllllll.lllljjjjjuuuuuuvvvvvvvvvvvvvvvvvvvvvv
...................................f...wwwwww.xmBBBmzzzzz.xxxl.kkkk.....kkkk........................
...................................f.........................l.kkkk.....kkkk........................
...................................f.........................l.kkkk.....kkkk........................
...................................f.ssssssssssssssssssssssssl.kkkk.....kkkk........................
ffffffffffffffffffffffffffffffffffff.wwww....yyyyyyy..zzz...yl.kkkk.....kkkk........................
...........CCCCCCCCCCCCCCCCCCCCCCC.f...wwwwww.xxxmzzzzzzz.mmml.kkkk.....kkkk........................
DDDDDDDDEEEEEEEEEEEEEFFFFFFEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEGGGGGHHHHIJJJJJJJJJJJJJJJJK
```

Legend: `a` [BufferLineBackground] · `b` [DevIconGo] · `c` [BufferLineFill] · `d` [ChangesTabInactive] · `e` [ChangesTabBranch] · `f` [WinSeparator] · `g` [DiffViewHeader] · `h` [ChangesBranchHeader] · `i` [ChangesCount] · `j` [DiffViewFold] · `k` [DiffViewLineNr] · `l` [DiffViewPadding] · `m` [@string] · `n` [FileTreeFolderIcon] · `o` [FileTreeCursorLine] · `p` [ChangesCommittedFile] · `q` [ChangesStatAdded] · `r` [ChangesStatRemoved] · `s` [@comment] · `t` [DiffViewArrowCommitted] · `u` [DiffViewGutterCommitted] · `v` [DiffViewCommitted] · `w` [@keyword] · `x` [@type.definition] · `y` [@function.call] · `z` [@function] · `A` [DiffViewCommittedWord] · `B` [@property] · `C` [PickerHint] · `D` [lualine_a_normal] · `E` [lualine_b_normal] · `F` [lualine_x_diagnostics_hint_command] · `G` [lualine_x_diagnostics_error_command] · `H` [lualine_x_diagnostics_warn_command] · `I` [StatuslineLangCapError] · `J` [StatuslineLangText] · `K` [StatuslineLangEdge] · `.` [Normal]

**Proposed — Branch diff in kind colours**: `100x30`, Normal, same fixture and keys; the editor area shows `4ccefde · main` → `Your version` (the working-tree `invoice.go` buffer, editable, Go syntax), drawn with `DiffViewChange`/`DiffViewAdd`/`DiffViewWord` like the Local tab (`renders/proposed_branch_diff.ansi`)

```text
                                     ◆ invoice.go                                                   
  Local 3   Branch 4   Comments 0  ┃ 4ccefde · main                           Your version          
 ◆ #482 feat/tax → main            ┃~~ 4 unchanged lines ~~~~ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 3 commits · merge-base 4ccefde    ┃                             5        5   ▏                     
                                   ┃   "example.com/billing/i    6        6   ▏ "example.com/billing
 ▾ □ internal/billing 4            ┃ )                           7        7   )                     
   ▾ ◆ invoice.go           +11 -2 ┃                             8        8                         
       ◆ invoice_test.go    +20 -1 ┃ // Invoice is a list of  »  9        9   // Invoice is a list o
   ▾ ◆ tax.go               +41 -0 ┃ type Invoice struct {      10       10   type Invoice struct { 
       ◆ tax_test.go        +33 -0 ┃   ID    string           » 11       11   ▏ ID    string // invo
                                   ┃   Lines []int              12       12   ▏ Lines []int         
                                   ┃   Tax   Rate               13       13   ▏ Tax   Rate          
                                   ┃ }                          14       14   }                     
                                   ┃                            15       15                         
                                   ┃ // Total sums the lines    16       16   // Total sums the line
                                   ┃ func (i Invoice) Total()   17       17   func (i Invoice) Total
                                   ┃   total := 0             » 18       18   ▏ var total int       
                                   ┃   for _, cents := range    19       19   ▏ for _, cents := rang
                                   ┃     total += cents         20       20   ▏ ▏ total += cents    
                                   ┃   }                        21       21   ▏ }                   
                                   ┃╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱ »╱╱╱╱      22   ▏ if i.Tax == nil {   
                                   ┃╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱  ╱╱╱╱      23   ▏ ▏ return total      
                                   ┃╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱  ╱╱╱╱      24   ▏ }                   
                                   ┃   return i.Tax.Apply(tot   22       25   ▏ return i.Tax.Apply(t
                                   ┃ }                          23       26   }                     
                                   ┃                            24       27                         
                                   ┃ // Due renders the total   25       28   // Due renders the tot
───────────────────────────────────┃ func (i Invoice) Due() s   26       29   func (i Invoice) Due()
           Commits c · Next tab ⌘G ┃   return fmt.Sprintf("du   27       30   ▏ return fmt.Sprintf("
 NORMAL  ⎇ feat/tax  ◆ #482                                               ◆ 0 ◆ 0 ◆ ◆ gleb-changes ◆
```

```text
....................................abaaaaaaaaaaaaaccccccccccccccccccccccccccccccccccccccccccccccccc
.ddddddddd.eeeeeeeeee.dddddddddddd.fggggggggggggggggggggggggg.gggggggggggggggggggggggggggggggggggggg
.hhhhhhiiiiiiiiiiiiiiii............fjjkkkkkkkkkkkkkkkkkkkjjjjljjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj
.iiiiiiiiiiiiiiiiiiiiiiiiiiiiii....f.........................l.kkkk.....kkkk..j.....................
...................................f...mmmmmmmmmmmmmmmmmmmmmml.kkkk.....kkkk..jjmmmmmmmmmmmmmmmmmmmm
.i.n..................i............f.........................l.kkkk.....kkkk........................
ooodooooooooooooooooooooooooooooooof.........................l.kkkk.....kkkk........................
.......b.ppppppppppppppp....qqq.rr.fsttttttttttttttttttttttttluvvvvsssssvvvvvvtttttttttttttttttttttt
...i.b.pppppp...............qqq.rr.f.wwww.xxxxxxx.wwwwww.....l.kkkk.....kkkk..wwww.xxxxxxx.wwwwww...
.......b.ppppppppppp........qqq.rr.fsssssssssssssssssssssssssluvvvvsssssvvvvvvssssssssssssssyttttttt
...................................f...xxxxx...zzz...........l.kkkk.....kkkk..jjxxxxx...zzz.........
...................................f...xxx...zzzz............l.kkkk.....kkkk..jjxxx...zzzz..........
...................................f.........................l.kkkk.....kkkk........................
...................................f.........................l.kkkk.....kkkk........................
...................................f.ttttttttttttttttttttttttl.kkkk.....kkkk..tttttttttttttttttttttt
...................................f.wwww....zzzzzzz..AAAAA..l.kkkk.....kkkk..wwww....zzzzzzz..AAAAA
...................................fsssssssssyyyyssssssssssssluvvvvsssssvvvvvvssyyyyssssssyyysssssss
...................................f...www.xm.xxxxx.ww.wwwww.l.kkkk.....kkkk..jjwww.xm.xxxxx.ww.wwww
...................................f.....xxxxx.ww.xxxxx......l.kkkk.....kkkk..jjjjxxxxx.ww.xxxxx....
...................................f.........................l.kkkk.....kkkk..jj....................
...................................fllllllllllllllllllllllllllBllllCCCCCDDDDDDCCCCCCCCCCCCCCCCCCCCCC
...................................fllllllllllllllllllllllllll.llllCCCCCDDDDDDCCCCCCCCCCCCCCCCCCCCCC
...................................fllllllllllllllllllllllllll.llllCCCCCDDDDDDCCCCCCCCCCCCCCCCCCCCCC
...................................f...wwwwww.xmEEEmAAAAA.xxxl.kkkk.....kkkk..jjwwwwww.xmEEEmAAAAA.x
...................................f.........................l.kkkk.....kkkk........................
...................................f.........................l.kkkk.....kkkk........................
...................................f.ttttttttttttttttttttttttl.kkkk.....kkkk..tttttttttttttttttttttt
ffffffffffffffffffffffffffffffffffff.wwww....zzzzzzz..AAA...zl.kkkk.....kkkk..wwww....zzzzzzz..AAA..
...........FFFFFFFFFFFFFFFFFFFFFFF.f...wwwwww.xxxmAAAAAAA.mmml.kkkk.....kkkk..jjwwwwww.xxxmAAAAAAA.m
GGGGGGGGHHHHHHHHHHHHHIIIIIIHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHJJJJJKKKKLMMMMMMMMMMMMMMMMN
```

Legend: `a` [BufferLineBufferSelected] · `b` [DevIconGo] · `c` [BufferLineFill] · `d` [ChangesTabInactive] · `e` [ChangesTabBranch] · `f` [WinSeparator] · `g` [DiffViewHeader] · `h` [ChangesBranchHeader] · `i` [ChangesCount] · `j` [DiffViewFold] · `k` [DiffViewLineNr] · `l` [DiffViewPadding] · `m` [@string] · `n` [FileTreeFolderIcon] · `o` [FileTreeCursorLine] · `p` [ChangesCommittedFile] · `q` [ChangesStatAdded] · `r` [ChangesStatRemoved] · `s` [DiffViewChange] · `t` [@comment] · `u` [DiffViewArrowChange] · `v` [DiffViewGutterChange] · `w` [@keyword] · `x` [@type.definition] · `y` [DiffViewWord] · `z` [@function.call] · `A` [@function] · `B` [DiffViewArrowAdd] · `C` [DiffViewAdd] · `D` [DiffViewGutterAdd] · `E` [@property] · `F` [PickerHint] · `G` [lualine_a_normal] · `H` [lualine_b_normal] · `I` [lualine_x_diagnostics_hint_command] · `J` [lualine_x_diagnostics_error_command] · `K` [lualine_x_diagnostics_warn_command] · `L` [StatuslineLangCapError] · `M` [StatuslineLangText] · `N` [StatuslineLangEdge] · `.` [Normal]

**Proposed — commit diff in kind colours**: `100x30`, Normal, same fixture, the panel clock at 2026-01-02T01:00:00Z, Branch tab after `c`; newest commit expanded, cursor on its `invoice.go`, the editor area shows `07cb52e · parent` → `e325463 · wire tax into Total`, read-only, with Go syntax on both sides and the Local tab's colours (`renders/proposed_commit_diff.ansi`)

```text
                                     ◆ invoice.go                                                   
  Local 3   Branch 4   Comments 0  ┃ 07cb52e · parent                         e325463 · wire tax int
 ◆ #482 feat/tax → main            ┃~~ 4 unchanged lines ~~~~ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                   ┃                             5        5                         
 ▸ ◆ All changes           4 files ┃   "example.com/billing/i    6        6     "example.com/billing
 ▾ ◆ e325463 wire tax into Tot… 1h ┃ )                           7        7   )                     
     ◆ invoice.go           +11 -2 ┃                             8        8                         
 ▸ ◆ 07cb52e add Rate and tax … 3h ┃ // Invoice is a list of  »  9        9   // Invoice is a list o
 ▸ ◆ b5435c5 add tax.go         1d ┃ type Invoice struct {      10       10   type Invoice struct { 
                                   ┃   ID    string             11       11     ID    string        
                                   ┃   Lines []int              12       12     Lines []int         
                                   ┃   Tax   Rate               13       13     Tax   Rate          
                                   ┃ }                          14       14   }                     
                                   ┃                            15       15                         
                                   ┃ // Total sums the lines    16       16   // Total sums the line
                                   ┃ func (i Invoice) Total()   17       17   func (i Invoice) Total
                                   ┃   total := 0             » 18       18     var total int       
                                   ┃   for _, cents := range    19       19     for _, cents := rang
                                   ┃     total += cents         20       20       total += cents    
                                   ┃   }                        21       21     }                   
                                   ┃╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱ »╱╱╱╱      22     if i.Tax == nil {   
                                   ┃╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱  ╱╱╱╱      23       return total      
                                   ┃╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱  ╱╱╱╱      24     }                   
                                   ┃   return i.Tax.Apply(tot   22       25     return i.Tax.Apply(t
                                   ┃ }                          23       26   }                     
                                   ┃                            24       27                         
                                   ┃ // Due renders the total   25       28   // Due renders the tot
───────────────────────────────────┃ func (i Invoice) Due() s   26       29   func (i Invoice) Due()
             Files c · Next tab ⌘G ┃   return fmt.Sprintf("du   27       30     return fmt.Sprintf("
 NORMAL  ⎇ feat/tax  ◆ #482                                               ◆ 0 ◆ 0 ◆ ◆ gleb-changes ◆
```

```text
....................................abbaaaaaaaaaaaaccccccccccccccccccccccccccccccccccccccccccccccccc
.ddddddddd.eeeeeeeeee.dddddddddddd.fggggggggggggggggggggggggg.gggggggggggggggggggggggggggggggggggggg
.hhhhhhiiiiiiiiiiiiiiii............fjjkkkkkkkkkkkkkkkkkkkjjjjljjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj
...................................f.........................l.kkkk.....kkkk........................
.i.m.nnnnnnnnnnn...........iiiiiii.f...ooooooooooooooooooooool.kkkk.....kkkk....oooooooooooooooooooo
.i.m.ppppppp..................i.ii.f.........................l.kkkk.....kkkk........................
qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqf.........................l.kkkk.....kkkk........................
.i.m.ppppppp..................i.ii.frssssssssssssssssssssssssltuuuurrrrruuuuuussssssssssssssssssssss
.i.m.ppppppp....................ii.f.vvvv.wwwwwww.vvvvvv.....l.kkkk.....kkkk..vvvv.wwwwwww.vvvvvv...
...................................f...ww....xxxxxx..........l.kkkk.....kkkk....ww....xxxxxx........
...................................f...wwwww...xxx...........l.kkkk.....kkkk....wwwww...xxx.........
...................................f...www...xxxx............l.kkkk.....kkkk....www...xxxx..........
...................................f.........................l.kkkk.....kkkk........................
...................................f.........................l.kkkk.....kkkk........................
...................................f.ssssssssssssssssssssssssl.kkkk.....kkkk..ssssssssssssssssssssss
...................................f.vvvv....xxxxxxx..yyyyy..l.kkkk.....kkkk..vvvv....xxxxxxx..yyyyy
...................................frrrrrrrrrzzzzrrrrrrrrrrrrltuuuurrrrruuuuuurrzzzzrrrrrrzzzrrrrrrr
...................................f...vvv.wo.wwwww.vv.vvvvv.l.kkkk.....kkkk....vvv.wo.wwwww.vv.vvvv
...................................f.....wwwww.vv.wwwww......l.kkkk.....kkkk......wwwww.vv.wwwww....
...................................f.........................l.kkkk.....kkkk........................
...................................fllllllllllllllllllllllllllAllllBBBBBCCCCCCBBBBBBBBBBBBBBBBBBBBBB
...................................fllllllllllllllllllllllllll.llllBBBBBCCCCCCBBBBBBBBBBBBBBBBBBBBBB
...................................fllllllllllllllllllllllllll.llllBBBBBCCCCCCBBBBBBBBBBBBBBBBBBBBBB
...................................f...vvvvvv.woDDDoyyyyy.wwwl.kkkk.....kkkk....vvvvvv.woDDDoyyyyy.w
...................................f.........................l.kkkk.....kkkk........................
...................................f.........................l.kkkk.....kkkk........................
...................................f.ssssssssssssssssssssssssl.kkkk.....kkkk..ssssssssssssssssssssss
ffffffffffffffffffffffffffffffffffff.vvvv....xxxxxxx..yyy...xl.kkkk.....kkkk..vvvv....xxxxxxx..yyy..
.............EEEEEEEEEEEEEEEEEEEEE.f...vvvvvv.wwwoyyyyyyy.oool.kkkk.....kkkk....vvvvvv.wwwoyyyyyyy.o
FFFFFFFFGGGGGGGGGGGGGHHHHHHGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGIIIIIJJJJKLLLLLLLLLLLLLLLLM
```

Legend: `a` [BufferLineBackground] · `b` [DevIconGo] · `c` [BufferLineFill] · `d` [ChangesTabInactive] · `e` [ChangesTabBranch] · `f` [WinSeparator] · `g` [DiffViewHeader] · `h` [ChangesBranchHeader] · `i` [ChangesCount] · `j` [DiffViewFold] · `k` [DiffViewLineNr] · `l` [DiffViewPadding] · `m` [ChangesCommittedFile] · `n` [ChangesRoot] · `o` [@string] · `p` [ChangesCommitHash] · `q` [FileTreeCursorLine] · `r` [DiffViewChange] · `s` [@comment] · `t` [DiffViewArrowChange] · `u` [DiffViewGutterChange] · `v` [@keyword] · `w` [@type.definition] · `x` [@function.call] · `y` [@function] · `z` [DiffViewWord] · `A` [DiffViewArrowAdd] · `B` [DiffViewAdd] · `C` [DiffViewGutterAdd] · `D` [@property] · `E` [PickerHint] · `F` [lualine_a_normal] · `G` [lualine_b_normal] · `H` [lualine_x_diagnostics_hint_command] · `I` [lualine_x_diagnostics_error_command] · `J` [lualine_x_diagnostics_warn_command] · `K` [StatuslineLangCapError] · `L` [StatuslineLangText] · `M` [StatuslineLangEdge] · `.` [Normal]

