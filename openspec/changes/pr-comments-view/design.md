## Context

`pr-review-threads` gives, per root with an open pull request, a cached `gleb.pr.Review` (`get(root)`), each
thread's place in a buffer (`locate(buf)`: a line or an unmapped reason) and `User GlebPrThreads` after every
fetch. `git-changes-tabs` gives the panel an ordered tab list (`lua/gleb/git/changes/tabs.lua`, descriptors
`id`, `title`, `group`, `available(view)`, `count(view)`), a winbar strip, the Branch header and the age
wording. `fix-tree-folding` gives the shared tree (`lua/gleb/ui/tree/`) and its fold keys. The diff view draws
filler virt_lines in a window-scoped namespace (`diff/view/render.lua`, `nvim__ns_set`) and keeps its panes
aligned.

The approved mocks are `r2_comments`, `r2_comments_peek`, `r3_truncate` and `r3_status_threads` (decision page,
2026-10-19). Prior art read as data:

- IntelliJ draws review threads as editor inlays under the line (`GHPRReviewEditorComponentsFactory`,
  `CodeReviewEditorInlaysModel`). They are collapsible, and resolved threads are folded.
- octo.nvim and gh-review.nvim show threads as signs plus a float, or in their own review buffers.
- No Neovim plugin draws them as virtual lines in the working file, so this change does.

## Goals / Non-Goals

**Goals:**
- See every thread of the PR in one place (the Comments tab), and each open one right under its code.
- Resolved threads cost one grey line, outdated ones none in code.
- The PR number and the open-thread count are always visible on a PR branch.

**Non-Goals:**
- Writing (replies, resolve): `pr-thread-window`.
- `LEFT`-side peeks in the diff view, new threads, reactions, review state.

## Decisions

1. **The Comments tab is a fourth descriptor kind: it owns the editor window.**
   - `tabs.lua` gains `{ id = "comments", title = "Comments", group = "ChangesTabComments", available =
     has_pr, count = open_threads, editor = "file" }`.
   - `available` reads `gleb.git.base.get(root).pr`. `count` reads `gleb.pr.threads.open_count` of the
     cached review, 0 before it loads.
   - Activating a tab whose descriptor has `editor = "file"` closes the panel-owned diff view, which the next
     diff tab reopens as today.
   - The cycle code is untouched: `next` returns `comments` after `branch` when it is available, and `close`
     after it.
   - The panel redraws its winbar and the Comments rows on `GlebPrThreads`.
2. **Rows** (`comments_tab.lua`, a `ui/tree` model with ids `comments:dir:<path>`, `comments:file:<path>`,
   `comments:thread:<id>`):
   - **Header:** the Branch tab's header row, then `<n> open · <m> resolved` (`ChangesCount`), then an empty
     line.
   - **Directories:** compacted like the Local and Branch tabs, sorted before files by name, with the open
     count (`ChangesCount`).
   - **Files:** expander, devicon, name (`ChangesCommittedFile`), then the open count when it is above 0.
   - **Threads** at depth 2:
     - `<icon> :<line> <author> <text>`: icon U+F0188 (`PrPeekIcon`), `:<line>` (`PrPeekMeta`; `line`, else
       `original_line`, else `file`), author (`PrPeekAuthor`, bold), then the first line of the first comment
       (`PrPeek`), cut (Decision 5) to `35 - 1 - <text column> - (tag + 1)`;
     - `outdated` (`PrThreadOutdated`) right-aligned with one column margin;
     - a resolved thread is U+F00C and the same text, the whole row in `PrThreadResolved`.
   - **Order:** open threads by line, then resolved ones by line.
   - Before the first fetch the tree is one `Loading…` row. After a failure with nothing cached it is the
     failure message from `pr-review-threads` (`PrPeekMeta`).
   - The panel's fold actions work unchanged through `ui/tree`.
   - The row cap is the Local tab's.
3. **Selection and Enter.**
   - A cursor move on the tab uses the panel's 50 ms debounce and generation guard.
   - A thread row: `locate` gives the line. The editor window (the panel's revalidated editor window) edits
     the file and the cursor is set to `(line, indent)`. The view scrolls only as Neovim does for a cursor
     move, with no `zz`.
   - An unmapped thread shows a scratch buffer `gleb-pr://hunk/<thread id>` holding the `diffHunk`, with
     `filetype=diff`, `modifiable` off and `bufhidden=wipe`.
   - A file row shows the file at its first thread.
   - `<CR>` (`changes.open`) does the same and focuses the editor window.
   - Buffers the tab loaded only for previews follow the panel's unload rule.
4. **Peeks** (`peek.lua`).
   - Namespace `gleb_pr_peek`, one extmark per thread on its mapped line (0-based `line - 1`, col 0) with
     `virt_lines` padded by the line's `indent()`. Threads on one line stack in the panel order.
   - **Collapsed:** `╰─ ` (`PrPeekMeta`), icon (`PrPeekIcon`), author (`PrPeekAuthor`), space, the cut first
     line (`PrPeek`), then ` +1 reply` or ` +<n> replies` (`PrPeekMeta`) when there are replies.
   - **Resolved:** `╰─ ` + U+F00C + ` Resolved · <author>: ` + the cut first line, all in `PrThreadResolved`.
     It never expands.
   - **Expanded** box of width `text width - indent`:
     - the top border `╭─` + ` <icon> PR #<n> · <k> comments ` (`PrPeekIcon`) + `─…╮` (`PrPeekMeta`);
     - per comment `│ <author> · <age>` (author `PrPeekAuthor`, the rest `PrPeekMeta`), then its body
       word-wrapped to the inner width (`text width - indent - 4`, `PrPeek`), each line padded to `… │`;
     - the bottom border `╰─…╯`.
     - Ages use the Branch tab's wording against `require("gleb.pr").now()`.
   - **Expansion:** a thread is expanded while its window is current with the cursor on its line, or while the
     current window is the Comments tab with the thread selected. `CursorMoved`, `WinEnter` and the tab's
     selection recompute the expanded set (augroup `gleb_pr_peek`). Only buffers whose expanded set changed
     are redrawn.
   - Outdated and unmapped threads get no extmark.
   - Peeks redraw on `GlebPrThreads`, `BufWinEnter` and `BufWritePost`. Between redraws the extmarks move with
     edits.
   - **Scope:** `nvim__ns_set(ns, { wins = … })` limits the namespace to normal editor windows. It is
     maintained on `BufWinEnter` and `WinClosed`, so a diff window showing the same buffer draws only the diff
     view's peeks (Decision 6).
5. **Cut** (`peek.truncate(text, width)`), with display widths:
   - Take the first line of the text and trim its trailing blanks. If it fits in `width`, keep it.
   - Otherwise take the longest prefix of `width - 1` cells. If the next character is not a space, drop back
     to the last space in the prefix, unless there is none (a single long word is hard-cut). Then trim it and
     append `…`.
   - A `width` below 1 gives `""`, and the caller then drops the space before it.
   - The examples are the scenario table and the renders:
     - the collapsed `:22` peek at 58 columns of text width, indent 2: budget 34, giving
       `Should a nil rate mean no tax at…`;
     - the resolved `:11` line: budget 32, giving `Should ID stay a string? The…`.
6. **Diff view peeks.**
   - `diff/view` gains a decoration provider list: `view.add_provider(fn(view) -> { right = { [line] =
     virt_lines } })`, called after each render.
   - `pr/peek.lua` registers one. For a diff view whose right side is a file in a root with a review, it maps
     the threads from the PR head onto the right side's lines. For the Local tab that is the buffer, for the
     Branch tab the `HEAD:<path>` text, both through `threads.map_line`.
   - The view puts those virt_lines in its window-scoped namespace under the right row, and the same number of
     blank `DiffViewPadding` virt_lines at the aligned left row.
   - Expansion follows the right window's cursor as in the editor.
7. **Statusline** (`pr/statusline.lua`, a lualine function component in `lualine_b` between `branch` and
   `diff`).
   - It resolves the root from `gleb.git.base`'s cached directory map (current file's directory, else the
     cwd), reads `get(root).pr` and `require("gleb.pr").get(root)`, and returns
     `%#PrStatuslineNumber#` U+F407 ` #482` and, with k > 0, `%#PrStatuslineThreads#  ` U+F0188 ` 3`.
   - Its `cond` is false without a pull request.
   - Per rule 2.5 it never requires `gleb.pr` on redraw: it checks `package.loaded`.
   - Both groups take `bg` from the statusline palette's section b colour, so the pill reads as one bar.
8. **Highlights** (`pr/highlights.lua`): the groups of Decisions 2, 4 and 7 from
   `gleb.colors.gruvbox-material.palette` (rule 8.7), set on load and on `ColorScheme` (augroup `gleb_pr_highlights`).

## Risks / Trade-offs

- **Virtual lines push code down.** An expanded thread of 8 lines moves the code under it while the cursor sits
  on the line. That is the point of expanding it, and it collapses as soon as the cursor leaves.
- **Window-scoped namespaces** (`nvim__ns_set`) are an underscore API; the diff view already depends on it. A
  change in Neovim's API breaks both, and the diff tests catch it.
- **Approximate lines.** Peeks inherit `pr-review-threads`' mapping: a thread on a rewritten block sits at the
  same offset in the new block.
- **Long Markdown.** Bodies are shown as raw Markdown, word-wrapped. Code fences and tables can look ragged in
  the expanded box; the thread window of the next change shows the same text with more room.

## Renders

Real captures (`100x30`, Hack Nerd Font cells, gruvbox-material). The editor's code, signs and peeks are real:
the capture script drew the proposed peeks as extmarks with the proposed groups. The panel and the statusline
component are drawn from the spec into those captures. The ANSI copies are in `renders/` (view them with
`command cat`).

- Stand-ins: `◆` for devicons, the PR icon (U+F407), the comment icon (U+F0188), the check (U+F00C) and the
  checkboxes.
- The editor shows relative line numbers (`relativenumber`), as the real config does.
- The purple bars in the sign column are `git-committed-signs`' layer (`GitCommittedSign`).
- The tab strip and header follow `git-changes-tabs`.
- Run `make colorize FILE=openspec/changes/pr-comments-view/design.md CASE=diff-view`, so that `StatuslineLang_go` exists. It then reports only this chain's new groups as unknown, plus `StatuslineLang_gleb_changes`, the chip logo group that exists only once a changes panel has drawn (`CASE=changes`).

Differences from the approved mocks:

- Every render shows the same four threads, so the peek screen also has the resolved `:11` line and the `:13`
  peek.
- Peeks start at the line's indent.
- The expanded box has no hint text.
- The tab strip is a winbar with no blank row under it (`git-changes-tabs`).
- The resolved line sits under line 11, where its thread is, instead of line 22.

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

**Current — statusline**: `100x1`, excerpt: statusline row, Normal, `sample.lua` in a temp git repo on `main` (`make render CASE=git-hunk`); no pull request component exists

```text
 NORMAL  ⎇ main  ◆ 1                                                               ◆ 0 ◆ 0 ◆ ◆ lua ◆
```

```text
aaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbcccccdddd.e.eeeeef
```

Legend: `a` [lualine_a_normal] · `b` [lualine_b_normal] · `c` [lualine_x_diagnostics_error_normal] · `d` [lualine_x_diagnostics_warn_normal] · `e` [StatuslineLangText] · `f` [StatuslineLangEdge] · `.` [Normal]

**Proposed — Comments tab (r2_comments)**: `100x30`, Normal, `billing-branch` fixture (branch `feat/tax`, pull request #482, the four canned threads, clock at 2026-01-02T01:00:00Z), `changes.review` three times, the panel cursor moved to the `:22` row and, after 100 ms, the editor window's view restored with `winrestview({ topline = 6 })`; the panel is current, the editor shows `invoice.go` with its cursor on line 22 and that thread expanded (`scrolloff` keeps the box in view, so line 10 is at the top)

```text
                                     ◆ invoice.go                                                   
  Local 3   Branch 4   Comments 3  ┃   12 type Invoice struct {                                     
 ◆ #482 feat/tax → main            ┃┃  11 ▏ ID    string // invoice number                          
 3 open · 1 resolved               ┃        ╰─ ◆ Resolved · ivan.p: Should ID stay a string? The…   
                                   ┃   10 ▏ Lines []int                                             
 ▾ ◆ internal/billing 3            ┃    9 ▏ Tax   Rate                                              
   ▾ ◆ invoice.go 2                ┃        ╰─ ◆ ivan.p Rate or *Rate here?                         
     ◆ :13 ivan.p Rate or *Rate…   ┃    8 }                                                         
     ◆ :22 maria.k Should a nil…   ┃    7                                                           
     ◆ :11 ivan.p Should ID stay…  ┃    6 // Total sums the lines and applies the tax rate.         
   ▾ ◆ tax.go 1                    ┃    5 func (i Invoice) Total() int {                            
     ◆ :18 maria.k Round… outdated ┃┃   4 ▏ var total int                                           
                                   ┃    3 ▏ for _, cents := range i.Lines {                         
                                   ┃    2 ▏ ▏ total += cents                                        
                                   ┃    1 ▏ }                                                       
                                   ┃┃ 22  ▏ if i.Tax == nil {                                       
                                   ┃        ╭─ ◆ PR #482 · 2 comments ─────────────────────────────╮
                                   ┃        │ maria.k · 2h                                         │
                                   ┃        │ Should a nil rate mean no tax at all?                │
                                   ┃        │ A missing config would silently drop tax.            │
                                   ┃        │ gleb-beloded · 1h                                    │
                                   ┃        │ Good catch, defaulting to Rate(0) and                │
                                   ┃        │ logging a warning.                                   │
                                   ┃        ╰──────────────────────────────────────────────────────╯
                                   ┃┃   1 ▏ ▏ return total                                          
                                   ┃┃   2 ▏ }                                                       
                                   ┃    3 ▏ return i.Tax.Apply(total)                               
                                   ┃    4 }                                                         
                                   ┃    5                                                           
 NORMAL  ⎇ feat/tax  ◆ #482  ◆ 3                                          ◆ 0 ◆ 0 ◆ ◆ gleb-changes ◆
```

```text
....................................abaaaaaaaaaaaaaccccccccccccccccccccccccccccccccccccccccccccccccc
.ddddddddd.dddddddddd.eeeeeeeeeeee.f..gggghhhh.iiiiiii.hhhhhh.......................................
.jjjjjjkkkkkkkkkkkkkkkk............fllggggggii....mmmmmm.nnnnnnnnnnnnnnnnn..........................
.kkkkkkkkkkkkkkkkkkk...............f..gggg..ooooooooooooooooooooooooooooooooooooooooooooooooooooo...
...................................f..ggggggiiiii...mmm.............................................
.p.q.rrrrrrrrrrrrrrrr.k............f..ggggggiii...mmmm..............................................
...p.b.ssssssssss.k................f..gggg..tttuuvvvvvv.wwww.ww.wwwww.wwwww.........................
.....u.ttt.vvvvvv.wwwwwwwwwwwwww...f..gggg..........................................................
xxxxxuxtttxvvvvvvvxwwwwwwwwwwwwwxxxf..gggg..........................................................
.....oooooooooooooooooooooooooooo..f..ggggnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn.........
...p.b.ssssss.k....................f..gggg..........................................................
.....u.ttt.vvvvvvv.wwwwww.yyyyyyyy.fzzggggtghhh.iiiii.mmm...........................................
...................................f..ggggtghhh.iu.iiiii.hh.hhhhh.iuAAAAA...........................
...................................f..ggggtgggiiiii.hh.iiiii........................................
...................................f..ggggtg........................................................
...................................fzzggggtghh.iuAAA.hh.AAA.........................................
...................................f..gggg..ttuuuuuuuuuuuuuuuuuuuuuuuutttttttttttttttttttttttttttttt
...................................f..gggg..ttvvvvvvvttttt........................................tt
...................................f..gggg..ttwwwwww.w.www.wwww.wwww.ww.www.ww.wwww...............tt
...................................f..gggg..ttw.wwwwwww.wwwwww.wwwww.wwwwwwww.wwww.wwww...........tt
...................................f..gggg..ttvvvvvvvvvvvvttttt...................................tt
...................................f..gggg..ttwwww.wwwwww.wwwwwwwwww.ww.wwwwwww.www...............tt
...................................f..gggg..ttwwwwwww.w.wwwwwwww..................................tt
...................................f..gggg..tttttttttttttttttttttttttttttttttttttttttttttttttttttttt
...................................fzzggggtggghhhhhh.iiiii..........................................
...................................fzzggggtg........................................................
...................................f..ggggtghhhhhh.iuAAAulllll.iiiii................................
...................................f..gggg..........................................................
...................................f..gggg..........................................................
BBBBBBBBCCCCCCCCCCCCCDDDDDDCCEEECCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCFFFFGGGGHIJIIIIIIIIIIIIIIK
```

Legend: `a` [BufferLineBufferSelected] · `b` [DevIconGo] · `c` [BufferLineFill] · `d` [ChangesTabInactive] · `e` [ChangesTabComments] · `f` [WinSeparator] · `g` [LineNr] · `h` [@keyword] · `i` [@type.definition] · `j` [ChangesBranchHeader] · `k` [ChangesCount] · `l` [GitSignsChange] · `m` [GitSignsAdd] · `n` [@comment] · `o` [PrThreadResolved] · `p` [FileTreeExpander] · `q` [FileTreeFolderIcon] · `r` [FileTreeFolderName] · `s` [ChangesCommittedFile] · `t` [PrPeekMeta] · `u` [PrPeekIcon] · `v` [PrPeekAuthor] · `w` [PrPeek] · `x` [FileTreeCursorLine] · `y` [PrThreadOutdated] · `z` [GitCommittedSign] · `A` [@property] · `B` [lualine_a_normal] · `C` [lualine_b_normal] · `D` [PrStatuslineNumber] · `E` [PrStatuslineThreads] · `F` [lualine_x_diagnostics_error_command] · `G` [lualine_x_diagnostics_warn_command] · `H` [StatuslineLangCapError] · `I` [StatuslineLangText] · `J` [StatuslineLang_gleb_changes] · `K` [StatuslineLangEdge] · `.` [Normal]

**Proposed — peeks in the editor (r2_comments_peek)**: `100x30`, Normal, the Comments tab screen above after the editor window is made current with `winrestview({ lnum = 18, topline = 6 })`: every thread is collapsed to one line

```text
                                    ▎◆ invoice.go                                                   
  Local 3   Branch 4   Comments 3  ┃   11 )                                                         
 ◆ #482 feat/tax → main            ┃   10                                                           
 3 open · 1 resolved               ┃┃   9 // Invoice is a list of line amounts in cents, with a tax 
                                   ┃    8 type Invoice struct {                                     
 ▾ ◆ internal/billing 3            ┃┃   7 ▏ ID    string // invoice number                          
   ▾ ◆ invoice.go 2                ┃        ╰─ ◆ Resolved · ivan.p: Should ID stay a string? The…   
     ◆ :13 ivan.p Rate or *Rate…   ┃    6 ▏ Lines []int                                             
     ◆ :22 maria.k Should a nil…   ┃    5 ▏ Tax   Rate                                              
     ◆ :11 ivan.p Should ID stay…  ┃        ╰─ ◆ ivan.p Rate or *Rate here?                         
   ▾ ◆ tax.go 1                    ┃    4 }                                                         
     ◆ :18 maria.k Round… outdated ┃    3                                                           
                                   ┃    2 // Total sums the lines and applies the tax rate.         
                                   ┃    1 func (i Invoice) Total() int {                            
                                   ┃┃ 18  ▏ var total int                                           
                                   ┃    1 ▏ for _, cents := range i.Lines {                         
                                   ┃    2 ▏ ▏ total += cents                                        
                                   ┃    3 ▏ }                                                       
                                   ┃┃   4 ▏ if i.Tax == nil {                                       
                                   ┃        ╰─ ◆ maria.k Should a nil rate mean no tax at… +1 reply 
                                   ┃┃   5 ▏ ▏ return total                                          
                                   ┃┃   6 ▏ }                                                       
                                   ┃    7 ▏ return i.Tax.Apply(total)                               
                                   ┃    8 }                                                         
                                   ┃    9                                                           
                                   ┃   10 // Due renders the total as dollars.                      
                                   ┃   11 func (i Invoice) Due() string {                           
                                   ┃   12 ▏ return fmt.Sprintf("due %s", money.Format(i.Total()))   
                                   ┃   13 }                                                         
 NORMAL  ⎇ feat/tax  ◆ #482  ◆ 3                                                    ◆ 0 ◆ 1 ◆ ◆ go ◆
```

```text
....................................abbcccccccccccdeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
.fffffffff.ffffffffff.gggggggggggg.h..iiii..........................................................
.jjjjjjkkkkkkkkkkkkkkkk............h..iiii..........................................................
.kkkkkkkkkkkkkkkkkkk...............hlliiiimmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm
...................................h..iiiinnnn.ooooooo.nnnnnn.......................................
.p.q.rrrrrrrrrrrrrrrr.k............hssiiiiiioo....tttttt.mmmmmmmmmmmmmmmmm..........................
...p.b.uuuuuuuuuu.k................h..iiii..vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv...
.....w.xxx.yyyyyy.zzzzzzzzzzzzzz...h..iiiiiiooooo...ttt.............................................
AAAAAwAxxxAyyyyyyyAzzzzzzzzzzzzzAAAh..iiiiiiooo...tttt..............................................
.....vvvvvvvvvvvvvvvvvvvvvvvvvvvv..h..iiii..xxxwwyyyyyy.zzzz.zz.zzzzz.zzzzz.........................
...p.b.uuuuuu.k....................h..iiii..........................................................
.....w.xxx.yyyyyyy.zzzzzz.BBBBBBBB.h..iiii..........................................................
...................................h..iiiimmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm.........
...................................h..iiii..........................................................
...................................hlliiiixinnn.ooooo.ttt...........................................
...................................h..iiiixinnn.ow.ooooo.nn.nnnnn.owCCCCC...........................
...................................h..iiiixiiiooooo.nn.ooooo........................................
...................................h..iiiixi........................................................
...................................hlliiiixinn.owCCC.nn.CCC.........................................
...................................h..iiii..xxxwwyyyyyyy.zzzzzz.z.zzz.zzzz.zzzz.zz.zzz.zzzxxxxxxxxx.
...................................hlliiiixiiinnnnnn.ooooo..........................................
...................................hlliiiixi........................................................
...................................h..iiiixinnnnnn.owCCCwsssss.ooooo................................
...................................h..iiii..........................................................
...................................h..iiii..........................................................
...................................h..iiiimmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm......................
...................................h..iiiinnnn....ttttttt..sss...tttttt.............................
...................................h..iiiiiinnnnnn.ooowsssssss.wwwwwwwww.ooooowssssss.owsssss.......
...................................h..iiii..........................................................
DDDDDDDDEEEEEEEEEEEEEFFFFFFEEGGGEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEHHHHIIIIJKLKKKKM
```

Legend: `a` [BufferLineIndicatorSelected] · `b` [DevIconGo] · `c` [BufferLineBufferSelected] · `d` [BufferLineCloseButtonSelected] · `e` [BufferLineFill] · `f` [ChangesTabInactive] · `g` [ChangesTabComments] · `h` [WinSeparator] · `i` [LineNr] · `j` [ChangesBranchHeader] · `k` [ChangesCount] · `l` [GitCommittedSign] · `m` [@comment] · `n` [@keyword] · `o` [@type.definition] · `p` [FileTreeExpander] · `q` [FileTreeFolderIcon] · `r` [FileTreeFolderName] · `s` [GitSignsChange] · `t` [GitSignsAdd] · `u` [ChangesCommittedFile] · `v` [PrThreadResolved] · `w` [PrPeekIcon] · `x` [PrPeekMeta] · `y` [PrPeekAuthor] · `z` [PrPeek] · `A` [FileTreeCursorLine] · `B` [PrThreadOutdated] · `C` [@property] · `D` [lualine_a_normal] · `E` [lualine_b_normal] · `F` [PrStatuslineNumber] · `G` [PrStatuslineThreads] · `H` [lualine_x_diagnostics_error_command] · `I` [lualine_x_diagnostics_warn_command] · `J` [StatuslineLangCapOk] · `K` [StatuslineLangText] · `L` [StatuslineLang_go] · `M` [StatuslineLangEdge] · `.` [Normal]

**Proposed — resolved thread, smart cut (r3_truncate)**: `65x3`, excerpt: editor rows of lines 11-12 of the peek screen above (columns 36-100); the resolved thread's first line is cut at the last word that fits the 58-column text width, then `…`

```text
┃┃   7 ▏ ID    string // invoice number                          
┃        ╰─ ◆ Resolved · ivan.p: Should ID stay a string? The…   
┃    6 ▏ Lines []int                                             
```

```text
abbccccccdd....eeeeee.fffffffffffffffff..........................
a..cccc..ggggggggggggggggggggggggggggggggggggggggggggggggggggg...
a..ccccccddddd...eee.............................................
```

Legend: `a` [WinSeparator] · `b` [GitSignsChange] · `c` [LineNr] · `d` [@type.definition] · `e` [GitSignsAdd] · `f` [@comment] · `g` [PrThreadResolved] · `.` [Normal]

**Proposed — statusline (r3_status_threads)**: `100x1`, excerpt: statusline row of the peek screen above, Normal, `invoice.go` on `feat/tax` with pull request #482 and 3 open threads

```text
 NORMAL  ⎇ feat/tax  ◆ #482  ◆ 3                                                    ◆ 0 ◆ 1 ◆ ◆ go ◆
```

```text
aaaaaaaabbbbbbbbbbbbbccccccbbdddbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbeeeeffffghihhhhj
```

Legend: `a` [lualine_a_normal] · `b` [lualine_b_normal] · `c` [PrStatuslineNumber] · `d` [PrStatuslineThreads] · `e` [lualine_x_diagnostics_error_command] · `f` [lualine_x_diagnostics_warn_command] · `g` [StatuslineLangCapOk] · `h` [StatuslineLangText] · `i` [StatuslineLang_go] · `j` [StatuslineLangEdge] · `.` [Normal]
