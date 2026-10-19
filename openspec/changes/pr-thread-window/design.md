## Context

`pr-review-threads` gives the cached review (`require("gleb.pr").get(root)`), `refresh`, the `gh api graphql`
runner and its failure messages. `pr-comments-view` gives the Comments tab, the peeks (`locate` per buffer)
and Enter on a thread row.

The approved mocks are `r3_thread_center` and `r3_confirm_footer` (decision page, 2026-10-19). Rule 8.9: the
border is drawn in full, the title is the only border text, and the hints are right-aligned in grey on the
last inner row under a joined rule. The picker's frame (`gleb.picker.frame`) already joins a hint band to its
border, and the AI commit popup closes when focus leaves it.

Mutations, verified by introspection on pgw.dev (GHES 3.22.1):

- `addPullRequestReviewThreadReply(input: { pullRequestReviewThreadId, body })` returns `comment`.
- `resolveReviewThread(input: { threadId })` and `unresolveReviewThread(input: { threadId })` return `thread`.

octo.nvim (`lua/octo/gh/mutations.lua`) uses the same three, as data.

## Goals / Non-Goals

**Goals:**
- Read a whole thread, reply to it and resolve or unresolve it without leaving Neovim.
- Every write is behind one explicit `y`, and the hints always say which key does what.
- A failed write never loses the draft.

**Non-Goals:**
- New threads, edits, deletes, suggestions, reactions, pending reviews, Markdown rendering.

## Decisions

1. **Layout** (`thread_window.lua`).
   - Width `W = min(72, columns - 4)`.
   - Height `H = messages + 1 + reply + 1 + 1 + 2`:
     - the messages part is the commented line, an empty line, every comment (`author · age`, then its body
       word-wrapped to `W - 4`), an empty line after each;
     - `reply` is the draft's lines, at least 3 and at most 8;
     - when `H` would exceed `lines - 4`, the messages part shrinks and shows its end.
   - Position: `col = floor((columns - W) / 2)`, `row = floor((lines - 1 - H) / 2)` (centred above the global
     statusline); on `100x30` that is row 5 and column 14, 0-based, `72x18`.
   - It is three stacked floats sharing their border cells, as the picker's frame joins its band:
     - the messages float, with the rounded top border, the title ` <file>:<line> · PR #<n> · <state> `
       (`FloatTitle`) and a bottom edge `├─…┤` with the ` Reply ` label;
     - the reply float, with a bottom edge `├─…┤`;
     - the hint float, with the rounded bottom border.
     - The border is `FloatBorder`, and only the title sits on the outer border (rule 8.9).
   - `<state>` is `resolved`, else `outdated`, else `open`.
   - The commented line is `<lnum, right-aligned in 4> <text>`, with the source buffer's treesitter captures
     at each column copied onto it. An unmapped thread shows the last four lines of its `diffHunk` instead,
     highlighted as the `diff` filetype.
   - Comments use `PrPeekAuthor` (bold) for the author, `PrPeekMeta` for ` · <age>` and `PrPeek` for the
     body. Ages are the Comments tab's.
   - Both the messages and reply buffers have filetype `gleb-pr-thread`; the messages buffer is not
     modifiable.
   - The empty reply shows `Write a reply…` (`PrReplyPlaceholder`) as virtual text.
2. **Opening.**
   - `pr.open_thread` looks up the cursor line in the current window's peeks (editor or diff right side),
     open threads first.
   - Enter on a Comments tab thread row (`changes.open`) shows its line as before, then opens the window for
     that thread.
   - Focus goes to the reply float in Normal mode. One thread window exists per tab page; opening another
     replaces it.
   - The window closes on `q` and when a scheduled `WinLeave` check finds focus outside its floats.
   - The reply text is kept in `state.drafts[thread.id]` on close and restored on open.
3. **Keys** (actions with `ft` scope; keys only in `settings/keymap.json`, rule 3.1):

   | Action | Key | Scope | Title |
   |---|---|---|---|
   | `pr.open_thread` | none | global | Open Review Thread |
   | `pr.thread_send` | `<CR>` | `gleb-pr-thread` | Reply to Thread |
   | `pr.thread_resolve` | `R` | `gleb-pr-thread` | Resolve or Unresolve Thread |
   | `pr.thread_open_web` | `gx` | `gleb-pr-thread` | Open Thread on Web |
   | `pr.thread_close` | `q` | `gleb-pr-thread` | Close Thread |
   | `pr.confirm_yes` | `y` | `gleb-pr-confirm` | Confirm |
   | `pr.confirm_no` | `n`, `<Esc>` | `gleb-pr-confirm` | Cancel |

   - All are in category `Git | Pull Request`.
   - The hint row is built from the first key of each action in Find Action's glyphs (`↩` for `<CR>`), like
     the Branch tab's hint row, so a reassigned key shows its new name.
   - `Reply ↩` is dropped when `can_reply` is false. `Resolve R` becomes `Unresolve R` for a resolved thread,
     and is dropped when the matching `can_resolve`/`can_unresolve` is false (then `R` does nothing).
   - `gx` calls `vim.ui.open(thread.comments[1].url)`.
4. **Confirmation states.** `normal` → `confirm_send` | `confirm_resolve` → `running` → `normal`.
   - Entering a confirm state sets the reply buffer `modifiable` off and its filetype to `gleb-pr-confirm`,
     so only the confirm actions are mapped there. It also fills the hint row with `PrConfirm` (whole row
     background) holding the question at the left and the keys right-aligned in `PrConfirmHint`:
     - send: `Send this reply to <first comment's author> on <host>?` and `Send y · Keep editing n`;
     - resolve: `Resolve this thread?` and `Resolve y · Cancel n`, or `Unresolve this thread?` and
       `Unresolve y · Cancel n`.
   - `n` or `<Esc>` restores the filetype, `modifiable`, the hint row and, after a send question, Insert mode
     at the end of the draft.
   - `y` enters `running`: the row reads `Sending...` or `Resolving...` and the confirm actions are no-ops.
     When the mutation ends:
     - on success: a silent forced `refresh(root)`, the window redrawn on `GlebPrThreads`, the draft cleared
       after a reply, and `Reply sent`, `Thread resolved` or `Thread unresolved` at INFO;
     - on failure: `Reply failed: <message>`, `Resolve failed: <message>` or `Unresolve failed: <message>` at
       ERROR, the draft kept, and back to `normal`.
5. **Mutations** (`gh.lua`, one-line documents like the queries):
   - `mutation AddReply($id:ID!,$body:String!){addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$id,body:$body}){comment{id}}}`
   - `mutation ResolveThread($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{id isResolved}}}`
   - `mutation UnresolveThread($id:ID!){unresolveReviewThread(input:{threadId:$id}){thread{id isResolved}}}`

   - argv: `gh api graphql -f query=<doc> -f id=<thread id>`, plus `-f body=<draft>` for a reply. The draft
     is the reply buffer's lines joined with `\n`, trailing blank lines dropped.
   - `-f` passes the text raw, so `@`, quotes and `$(…)` reach GitHub as typed. There is no shell.
   - The env and timeout are the same as for the queries.
   - The message is `gh.failure`'s text without its `PR comments unavailable: ` prefix.
   - `refresh` gains `opts.silent` (no INFO), used after a mutation.
6. **Colours** (`pr/highlights.lua`, palette helpers): `PrConfirm` = yellow, bold, on `blend(yellow, bg0,
   0.8)`; `PrConfirmHint` = fg1 on the same; `PrReplyPlaceholder` = grey0, italic.

## Risks / Trade-offs

- **Pending reviews.** When the user has a pending review on the pull request, GitHub may attach the reply to
  it, and the reply stays invisible to others until that review is submitted. This config never creates
  pending reviews, so this only happens when one was started on the web. Out of scope.
- **Composite floats.** Three floats must move and close together. One owner table holds them, with a
  `WinClosed` handler that closes the rest. Resizing (`VimResized`) recomputes the layout like the picker.
- **A write that succeeds while its refresh fails** shows the new state only after the next fetch. The WARN
  rules of `pr-review-threads` cover the failed refresh.

## Renders

Real captures, as in `pr-comments-view` (same fixture, threads and clock). The editor behind the window is a
real capture with the thread collapsed, because the editor is no longer current. The window is drawn from
this design; its commented line copies the editor's real cells for line 22. ANSI copies are in `renders/`.
Stand-ins: `◆` for devicons and the PR, comment and check glyphs. Run `make colorize
FILE=openspec/changes/pr-thread-window/design.md CASE=diff-view`. It reports only this chain's new groups as
unknown, plus `StatuslineLang_gleb_changes`, the chip logo group of the Current render that exists only once a
changes panel has drawn.

Differences from the approved mocks:

- The title and hints are as in the mock, with the hint row one column in from the border.
- The draft is plain text, with the cursor after it (the confirm state keeps the cursor in the read-only
  reply).
- The commit in the draft is the fixture's `e325463`.

**Current**: `100x30`, Normal, `internal/billing/invoice.go` of the `billing` fixture, `changes.toggle`, then the panel's diff view of the cursor row (`make render CASE=changes`)

```text
                                     ◆ invoice.go                                                   
 ▾ ◪ Changes 5 files               ┃ 4ccefde · HEAD                           Your version          
   ▾ □ internal/billing 4          ┃~~ 4 unchanged lines ~~~~ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     ▾ ☐ ◆ invoice.go       +12 -3 ┃                             5        5   ▏                     
         ☐ ◆ invoice_test.… +20 -1 ┃   "example.com/billing/i    6        6   ▏ "example.com/billing
     ▾ ☑ ◆ tax.go           +41 -0 ┃ )                           7        7   )                     
         ☑ ◆ tax_test.go    +33 -0 ┃                             8        8                         
   ▾ □ web/src 1                   ┃ // Invoice is a list of  »  9        9 ☐ // Invoice is a list o
       ☐ ◆ price.ts          +4 -4 ┃ type Invoice struct {      10       10   type Invoice struct { 
 ▾ ☐ Unversioned Files 1 file      ┃   ID    string           » 11       11 ☐ ▏ ID    string // invo
     ☐ ◆ notes.md                  ┃   Lines []int              12       12   ▏ Lines []int         
                                   ┃   Tax   Rate               13       13   ▏ Tax   Rate          
                                   ┃ }                          14       14   }                     
                                   ┃                            15       15                         
                                   ┃ // Total sums the lines    16       16   // Total sums the line
                                   ┃ func (i Invoice) Total()   17       17   func (i Invoice) Total
                                   ┃   total := 0             » 18       18 ☐ ▏ var total int       
                                   ┃   for _, cents := range    19       19   ▏ for _, cents := rang
                                   ┃     total += cents         20       20   ▏ ▏ total += cents    
                                   ┃   }                        21       21   ▏ }                   
                                   ┃╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱ »╱╱╱╱      22 ☐ ▏ if i.Tax == nil {   
                                   ┃╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱  ╱╱╱╱      23   ▏ ▏ return total      
                                   ┃╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱  ╱╱╱╱      24   ▏ }                   
                                   ┃   return i.Tax.Apply(tot   22       25   ▏ return i.Tax.Apply(t
                                   ┃ }                          23       26   }                     
                                   ┃                            24       27                         
                                   ┃ // Due renders the total   25       28   // Due renders the tot
                                   ┃ func (i Invoice) Due() s   26       29   func (i Invoice) Due()
                                   ┃   return fmt.Sprintf("du   27       30   ▏ return fmt.Sprintf("
 NORMAL                                                                   ◆ 0 ◆ 0 ◆ ◆ gleb-changes ◆
```

```text
....................................abaaaaaaaaaaaaaccccccccccccccccccccccccccccccccccccccccccccccccc
.d.d.eeeeeee.ddddddd...............fgggggggggggggggggggggggggfgggggggggggggggggggggggggggggggggggggg
...d.h..................d..........fiigggggggggggggggggggiiiifiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
jjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjf.........................f.gggg.....gggg..i.....................
.........d.b.hhhhhhhhhhhhhd.kkk.ll.f...mmmmmmmmmmmmmmmmmmmmmmf.gggg.....gggg..iimmmmmmmmmmmmmmmmmmmm
.....d.d.b.kkkkkk...........kkk.ll.f.........................f.gggg.....gggg........................
.........d.b.kkkkkkkkkkk....kkk.ll.f.........................f.gggg.....gggg........................
...d.h.........d...................finnnnnnnnnnnnnnnnnnnnnnnnfoppppiiiiippppppnnnnnnnnnnnnnnnnnnnnnn
.......d...hhhhhhhh..........kk.ll.f.qqqq.rrrrrrr.qqqqqq.....f.gggg.....gggg..qqqq.sssssss.qqqqqq...
.d.d.eeeeeeeeeeeeeeeee.dddddd......fittttttttttttttttttttttttfoppppiiiiippppppiittttttttttttunnnnnnn
.....d.v.wwwwwwww..................f...rrrrr...sss...........f.gggg.....gggg..iirrrrr...sss.........
...................................f...rrr...ssss............f.gggg.....gggg..iirrr...ssss..........
...................................f.........................f.gggg.....gggg........................
...................................f.........................f.gggg.....gggg........................
...................................f.nnnnnnnnnnnnnnnnnnnnnnnnf.gggg.....gggg..nnnnnnnnnnnnnnnnnnnnnn
...................................f.qqqq....sssssss..xxxxx..f.gggg.....gggg..qqqq..r.sssssss..xxxxx
...................................fittttttttuuuuttttttttttttfoppppiiiiippppppiiuuuuttttttuuuttttttt
...................................f...qqq.rm.rrrrr.qq.qqqqq.f.gggg.....gggg..iiqqq.rm.rrrrr.qq.qqqq
...................................f.....rrrrr.qq.rrrrr......f.gggg.....gggg..iiiirrrrr.qq.rrrrr....
...................................f.........................f.gggg.....gggg..ii....................
...................................fffffffffffffffffffffffffffyffffiiiiizzzzzziiAAAAAAAAAAAAAAAAAAAA
...................................fffffffffffffffffffffffffff.ffffiiiiizzzzzziiiiAAAAAAAAAAAAAAAAAA
...................................fffffffffffffffffffffffffff.ffffiiiiizzzzzziiAAAAAAAAAAAAAAAAAAAA
...................................f...qqqqqq.rmBBBmxxxxx.rrrf.gggg.....gggg..iiqqqqqq.rmrrrmxxxxx.r
...................................f.........................f.gggg.....gggg........................
...................................f.........................f.gggg.....gggg........................
...................................f.nnnnnnnnnnnnnnnnnnnnnnnnf.gggg.....gggg..nnnnnnnnnnnnnnnnnnnnnn
...................................f.qqqq....sssssss..xxx...sf.gggg.....gggg..qqqq..r.sssssss..xxx..
...................................f...qqqqqq.rrrmxxxxxxx.mmmf.gggg.....gggg..iiqqqqqq....mxxxxxxx.m
CCCCCCCCDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDEEEEEFFFFGHIHHHHHHHHHHHHHHJ
```

Legend: `a` [BufferLineBufferSelected] · `b` [DevIconGo] · `c` [BufferLineFill] · `d` [ChangesCheckbox] · `e` [ChangesRoot] · `f` [DiffViewPadding] · `g` [DiffViewHeader] · `h` [FileTreeFolderIcon] · `i` [DiffViewFold] · `j` [FileTreeCursorLine] · `k` [FileTreeGitAdded] · `l` [ChangesStatRemoved] · `m` [@string] · `n` [@comment] · `o` [DiffViewArrowChange] · `p` [DiffViewGutterChange] · `q` [@keyword] · `r` [@variable.member] · `s` [@type] · `t` [DiffViewChange] · `u` [DiffViewWord] · `v` [DevIconMd] · `w` [FileTreeGitUntracked] · `x` [@function] · `y` [DiffViewArrowAdd] · `z` [DiffViewGutterAdd] · `A` [DiffViewAdd] · `B` [@property] · `C` [lualine_a_normal] · `D` [lualine_b_normal] · `E` [lualine_x_diagnostics_error_normal] · `F` [lualine_x_diagnostics_warn_normal] · `G` [StatuslineLangCapError] · `H` [StatuslineLangText] · `I` [StatuslineLang_gleb_changes] · `J` [StatuslineLangEdge] · `.` [Normal]

**Proposed — thread window (r3_thread_center)**: `100x30`, Normal, the Comments tab screen of pr-comments-view after `<CR>` on the `:22` row: the centred thread window, focus in its empty reply area; behind it the editor, no longer current, shows the thread collapsed

```text
                                     ◆ invoice.go                                                   
  Local 3   Branch 4   Comments 3  ┃   12 type Invoice struct {                                     
 ◆ #482 feat/tax → main            ┃┃  11 ▏ ID    string // invoice number                          
 3 open · 1 resolved               ┃        ╰─ ◆ Resolved · ivan.p: Should ID stay a string? The…   
                                   ┃   10 ▏ Lines []int                                             
 ▾ ◆ internal/╭ invoice.go:22 · PR #482 · open ──────────────────────────────────────╮              
   ▾ ◆ invoice│   22   if i.Tax == nil {                                             │              
     ◆ :13 iva│                                                                      │              
     ◆ :22 mar│ maria.k · 2h                                                         │              
     ◆ :11 iva│ Should a nil rate mean no tax at all?                                │rate.         
   ▾ ◆ tax.go │ A missing config would silently drop tax.                            │              
     ◆ :18 mar│                                                                      │              
              │ gleb-beloded · 1h                                                    │              
              │ Good catch, defaulting to Rate(0) and                                │              
              │ logging a warning.                                                   │              
              │                                                                      │              
              ├─ Reply ──────────────────────────────────────────────────────────────┤ at… +1 reply 
              │ Write a reply…                                                       │              
              │                                                                      │              
              │                                                                      │              
              ├──────────────────────────────────────────────────────────────────────┤              
              │                       Reply ↩ · Resolve R · Open on web gx · Close q │              
              ╰──────────────────────────────────────────────────────────────────────╯              
                                   ┃    7 func (i Invoice) Due() string {                           
                                   ┃    8 ▏ return fmt.Sprintf("due %s", money.Format(i.Total()))   
                                   ┃    9 }                                                         
                                   ┃   10                                                           
                                   ┃   11 // Paid reports whether nothing is due.                   
                                   ┃   12 func (i Invoice) Paid() bool {                            
 NORMAL  ⎇ feat/tax  ◆ #482  ◆ 3                                                    ◆ 0 ◆ 1 ◆ ◆ go ◆
```

```text
....................................abaaaaaaaaaaaaaccccccccccccccccccccccccccccccccccccccccccccccccc
.ddddddddd.dddddddddd.eeeeeeeeeeee.f..gggghhhh.iiiiiii.hhhhhh.......................................
.jjjjjjkkkkkkkkkkkkkkkk............fllggggggii....mmmmmm.nnnnnnnnnnnnnnnnn..........................
.kkkkkkkkkkkkkkkkkkk...............f..gggg..ooooooooooooooooooooooooooooooooooooooooooooooooooooo...
...................................f..ggggggiiiii...mmm.............................................
.p.q.rrrrrrrrrsttttttttttttttttttttttttttttttttsssssssssssssssssssssssssssssssssssssss..............
...p.b.uuuuuuus.ggggg.ghh.ivwww.hh.www...............................................s..............
.....v.xxx.yyys......................................................................s..............
zzzzzvzxxxzyyys.yyyyyyyxxxxx.........................................................s..............
.....ooooooooos.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA................................snnnnn.........
...p.b.uuuuuu.s.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA............................s..............
.....v.xxx.yyys......................................................................s..............
..............s.yyyyyyyyyyyyxxxxx....................................................s..............
..............s.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA................................s..............
..............s.AAAAAAAAAAAAAAAAAA...................................................s..............
..............s......................................................................s..............
..............ssxxxxxxxsssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss.AAAxxxxxxxxx.
..............s.BBBBBBBBBBBBBB.......................................................s..............
..............s......................................................................s..............
..............s......................................................................s..............
..............ssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss..............
..............s.......................CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC.s..............
..............ssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss..............
...................................f..gggghhhh....mmmmmmm..lll...mmmmmm.............................
...................................f..gggggghhhhhh.iiivlllllll.vvvvvvvvv.iiiiivllllll.ivlllll.......
...................................f..gggg..........................................................
...................................f..gggg..........................................................
...................................f..ggggnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn...................
...................................f..gggghhhh....mmmmmmm..llll...mmmm..............................
DDDDDDDDEEEEEEEEEEEEEFFFFFFEEGGGEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEHHHHIIIIJKLKKKKM
```

Legend: `a` [BufferLineBufferSelected] · `b` [DevIconGo] · `c` [BufferLineFill] · `d` [ChangesTabInactive] · `e` [ChangesTabComments] · `f` [WinSeparator] · `g` [LineNr] · `h` [@keyword] · `i` [@type.definition] · `j` [ChangesBranchHeader] · `k` [ChangesCount] · `l` [GitSignsChange] · `m` [GitSignsAdd] · `n` [@comment] · `o` [PrThreadResolved] · `p` [FileTreeExpander] · `q` [FileTreeFolderIcon] · `r` [FileTreeFolderName] · `s` [FloatBorder] · `t` [FloatTitle] · `u` [ChangesCommittedFile] · `v` [PrPeekIcon] · `w` [@property] · `x` [PrPeekMeta] · `y` [PrPeekAuthor] · `z` [FileTreeCursorLine] · `A` [PrPeek] · `B` [PrReplyPlaceholder] · `C` [PickerHint] · `D` [lualine_a_normal] · `E` [lualine_b_normal] · `F` [PrStatuslineNumber] · `G` [PrStatuslineThreads] · `H` [lualine_x_diagnostics_error_command] · `I` [lualine_x_diagnostics_warn_command] · `J` [StatuslineLangCapOk] · `K` [StatuslineLangText] · `L` [StatuslineLang_go] · `M` [StatuslineLangEdge] · `.` [Normal]

**Proposed — send confirmation (r3_confirm_footer)**: `100x30`, Normal, the thread window above after `i`, typing `Defaulting to Rate(0) now, see e325463.`, `<Esc>` and `<CR>`: the hint row asks before anything is sent

```text
                                     ◆ invoice.go                                                   
  Local 3   Branch 4   Comments 3  ┃   12 type Invoice struct {                                     
 ◆ #482 feat/tax → main            ┃┃  11 ▏ ID    string // invoice number                          
 3 open · 1 resolved               ┃        ╰─ ◆ Resolved · ivan.p: Should ID stay a string? The…   
                                   ┃   10 ▏ Lines []int                                             
 ▾ ◆ internal/╭ invoice.go:22 · PR #482 · open ──────────────────────────────────────╮              
   ▾ ◆ invoice│   22   if i.Tax == nil {                                             │              
     ◆ :13 iva│                                                                      │              
     ◆ :22 mar│ maria.k · 2h                                                         │              
     ◆ :11 iva│ Should a nil rate mean no tax at all?                                │rate.         
   ▾ ◆ tax.go │ A missing config would silently drop tax.                            │              
     ◆ :18 mar│                                                                      │              
              │ gleb-beloded · 1h                                                    │              
              │ Good catch, defaulting to Rate(0) and                                │              
              │ logging a warning.                                                   │              
              │                                                                      │              
              ├─ Reply ──────────────────────────────────────────────────────────────┤ at… +1 reply 
              │ Defaulting to Rate(0) now, see e325463.█                             │              
              │                                                                      │              
              │                                                                      │              
              ├──────────────────────────────────────────────────────────────────────┤              
              │ Send this reply to maria.k on pgw.dev?       Send y · Keep editing n │              
              ╰──────────────────────────────────────────────────────────────────────╯              
                                   ┃    7 func (i Invoice) Due() string {                           
                                   ┃    8 ▏ return fmt.Sprintf("due %s", money.Format(i.Total()))   
                                   ┃    9 }                                                         
                                   ┃   10                                                           
                                   ┃   11 // Paid reports whether nothing is due.                   
                                   ┃   12 func (i Invoice) Paid() bool {                            
 NORMAL  ⎇ feat/tax  ◆ #482  ◆ 3                                                    ◆ 0 ◆ 1 ◆ ◆ go ◆
```

```text
....................................abaaaaaaaaaaaaaccccccccccccccccccccccccccccccccccccccccccccccccc
.ddddddddd.dddddddddd.eeeeeeeeeeee.f..gggghhhh.iiiiiii.hhhhhh.......................................
.jjjjjjkkkkkkkkkkkkkkkk............fllggggggii....mmmmmm.nnnnnnnnnnnnnnnnn..........................
.kkkkkkkkkkkkkkkkkkk...............f..gggg..ooooooooooooooooooooooooooooooooooooooooooooooooooooo...
...................................f..ggggggiiiii...mmm.............................................
.p.q.rrrrrrrrrsttttttttttttttttttttttttttttttttsssssssssssssssssssssssssssssssssssssss..............
...p.b.uuuuuuus.ggggg.ghh.ivwww.hh.www...............................................s..............
.....v.xxx.yyys......................................................................s..............
zzzzzvzxxxzyyys.yyyyyyyxxxxx.........................................................s..............
.....ooooooooos.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA................................snnnnn.........
...p.b.uuuuuu.s.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA............................s..............
.....v.xxx.yyys......................................................................s..............
..............s.yyyyyyyyyyyyxxxxx....................................................s..............
..............s.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA................................s..............
..............s.AAAAAAAAAAAAAAAAAA...................................................s..............
..............s......................................................................s..............
..............ssxxxxxxxsssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss.AAAxxxxxxxxx.
..............s......................................................................s..............
..............s......................................................................s..............
..............s......................................................................s..............
..............ssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss..............
..............sBCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBs..............
..............ssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss..............
...................................f..gggghhhh....mmmmmmm..lll...mmmmmm.............................
...................................f..gggggghhhhhh.iiivlllllll.vvvvvvvvv.iiiiivllllll.ivlllll.......
...................................f..gggg..........................................................
...................................f..gggg..........................................................
...................................f..ggggnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn...................
...................................f..gggghhhh....mmmmmmm..llll...mmmm..............................
DDDDDDDDEEEEEEEEEEEEEFFFFFFEEGGGEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEHHHHIIIIJKLKKKKM
```

Legend: `a` [BufferLineBufferSelected] · `b` [DevIconGo] · `c` [BufferLineFill] · `d` [ChangesTabInactive] · `e` [ChangesTabComments] · `f` [WinSeparator] · `g` [LineNr] · `h` [@keyword] · `i` [@type.definition] · `j` [ChangesBranchHeader] · `k` [ChangesCount] · `l` [GitSignsChange] · `m` [GitSignsAdd] · `n` [@comment] · `o` [PrThreadResolved] · `p` [FileTreeExpander] · `q` [FileTreeFolderIcon] · `r` [FileTreeFolderName] · `s` [FloatBorder] · `t` [FloatTitle] · `u` [ChangesCommittedFile] · `v` [PrPeekIcon] · `w` [@property] · `x` [PrPeekMeta] · `y` [PrPeekAuthor] · `z` [FileTreeCursorLine] · `A` [PrPeek] · `B` [PrConfirmHint] · `C` [PrConfirm] · `D` [lualine_a_normal] · `E` [lualine_b_normal] · `F` [PrStatuslineNumber] · `G` [PrStatuslineThreads] · `H` [lualine_x_diagnostics_error_command] · `I` [lualine_x_diagnostics_warn_command] · `J` [StatuslineLangCapOk] · `K` [StatuslineLangText] · `L` [StatuslineLang_go] · `M` [StatuslineLangEdge] · `.` [Normal]
