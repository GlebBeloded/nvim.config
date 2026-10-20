## Context

The changes panel (`lua/gleb/git/changes/`) lists uncommitted work from `git status` and shows the selected
file in the owned diff view (`lua/gleb/diff/view/`) with `HEAD` on the left and the file buffer on the right.
`changes.review` (Cmd+G, `<A-g>`) opens or focuses it. `git-branch-base` adds `gleb.git.base`: the base of the
current branch (the pull request's base when `gh` finds one, else `origin/<default>`), the merge-base, HEAD,
the PR number and the default-branch rule, cached and refreshed on git events. `git-committed-signs` adds the
purple layer in the editor gutter. `fix-tree-folding` gives every tree `lua/gleb/ui/tree/` and the same fold
keys. This change adds the committed side to the panel: tabs, a Branch tab with files and commits, and purple
read-only diffs.

## Goals / Non-Goals

**Goals:**

- Review the whole branch against its base, and each commit, from the panel the user already uses.
- One key, Cmd+G, cycles Local → Branch → close (the approved decision), with the first-press and default-branch
  rules.
- A tab list that `pr-comments-view` extends with a Comments tab without touching the cycle.
- Keep every Local tab behaviour and row as it is.

**Non-Goals:**

- Review threads, the Comments tab and the statusline PR number (`pr-comments-view`).
- Staging, reverting or editing committed content; fetching or rebasing.
- A Branch-like view on the default branch.

## Decisions

1. **The strip is the panel's winbar.** `tabs.lua` holds an ordered list of tab descriptors
   (`id`, `title`, `group`, `available(view)`, `count(view)`); the winbar string is built from it with
   `%#<group>#` pills and refreshed on every redraw of the panel. Because it is a winbar, the tree's buffer lines
   do not move, so every row scenario of the Local tab holds and the tab row lines up with the diff view's label
   winbar. The panel's `winhighlight` maps `WinBar`/`WinBarNC` to `FileTreeNormal`, so the gaps between pills are
   the panel background. `pr-comments-view` appends `{ id = "comments", … }`. Alternative: a buffer line for the
   strip (the mock's blank row under it) — rejected, it shifts every row and breaks row scenarios for no gain.
2. **Cycle rules are pure.** `tabs.first(state)` and `tabs.next(state)` take
   `{ active, available, local_count }` and return a tab id or `"close"`. `first`: `branch` when `local_count`
   is 0 and `branch` is available, else `local`. `next`: the next available tab after `active`, or `close`
   after the last. `changes.review` with the panel open in the current tab page applies `next`, whichever window
   has focus, then focuses the panel and shows the diff of the row under the cursor. The first press waits for
   the status refresh and the local part of `gleb.git.base` (merge-base from git refs) before choosing; the PR
   number fills the header later and never changes the choice.
3. **No new plugin.** diffview.nvim is installed (merges, history) and can open `origin/main...HEAD`, but in its
   own tab page with its own file panel and diff windows; the user reviews in the changes panel and the owned diff
   view, and wants the tabs there. gitsigns' `change_base` moves the whole sign column to one base, which
   `git-committed-signs` replaced with a second layer. The Branch tab is a model (`branch.lua`) plus the shared
   tree view.
4. **Branch model (`branch.lua`).** Inputs from `gleb.git.base`: `merge_base`, `head`, the base's short name
   (`main` for `origin/main`), the branch name and the optional PR number. Commands, each async with
   `vim.system` and the panel's generation guard:
   - files: `git diff --name-status -z -M <merge-base> HEAD` and `git diff --numstat -z -M <merge-base> HEAD`
     (git ignores `--numstat` when both are given, so they run separately), joined by path like the Local stats;
   - commits: `git log --format=%H%x00%P%x00%ct%x00%s%x00 -z <merge-base>..HEAD`;
   - a commit's files: `git diff --name-status -z -M <commit>^ <commit>` and its `--numstat`, loaded when the
     commit is first expanded and cached by commit hash.
   Rows are `ui/tree` nodes with stable ids (`branch:file:<path>`, `branch:commit:<hash>`,
   `branch:commit:<hash>:<path>`, `branch:all`), so folds and the cursor survive refreshes. Directory compaction
   and nesting reuse the Local tab's grouping. The row cap is the Local tab's. `summary(count, oid)` and
   `age(seconds)` are pure. `age`: under 60 s `now`, under 1 h `<m>m`, under 1 d `<h>h`, under 14 d `<d>d`, under
   60 d `<w>w`, under 365 d `<mo>mo`, else `<y>y` (floors). `M.now()` returns `os.time()`; tests replace it.
5. **Branch diffs reuse the panel's diff pipeline.** `git.load_diff` gains a branch variant that reads both
   sides with `git show <rev>:<path>` (the left one by the original path for a rename) and calls back with
   `committed = true`, `actionable = false`, no `right_buf`, the filetype from the path and the labels of the
   proposal. Debounce, selection generation, `]f` (`on_next_file` walks the active tab's file rows) and
   "contentless diff" handling are shared with the Local tab. `<CR>` on a Branch file row edits the working-tree
   file like the Local tab; on a directory, commit or `All changes` row it toggles the fold.
6. **Committed diffs in the diff view.** The diff view's spec gains `committed?: boolean`. Rendering already
   builds group names as `"DiffView" .. kind`; with `committed` the kind suffix is `Committed` for added, changed
   and deleted rows (`DiffViewCommitted`, `DiffViewGutterCommitted`, `DiffViewArrowCommitted`) and the word group
   is `DiffViewCommittedWord`. Moved blocks keep `DiffViewMoved*`. The checkbox column is blank, and both buffers
   are read-only because the spec is not actionable and has no `right_buf`. `highlights.lua` adds the four groups
   from `palette.foreground.purple` with `util.blend(purple, bg0, 0.74)` (0.5 for words), the ratio
   `git-committed-signs` uses for its purple.
7. **Hint row is a float on the panel's last two rows.** `hint.lua` opens a non-focusable, borderless float
   (`relative = "win"` on the panel, `row = height - 2`, full panel width, two lines, `winhighlight`
   `Normal:PickerHint`), line 1 a `─` rule in `PickerBorder`, line 2 the right-aligned hint with a one-column
   margin. Keys come from `settings/keymap.json` through the Find Action key glyphs
   (`find_action/rows.lua`: `<A-g>` → `⌘G`). The panel adds two virtual blank lines after its last row while the
   hint is shown, so `G` scrolls the last row above the rule. It follows `WinResized`/`VimResized`, and closes with
   the panel or when another tab becomes active. Existing groups are reused (rule 8.9), no new `ChangesHint`.
8. **Fixture `billing-branch`** (`tests/fixtures/build.sh`), hermetic like the others:
   1. build the `billing` fixture's committed state on `main` (commit `4ccefde`, 2026-01-01T00:00:00Z);
   2. `git update-ref refs/remotes/origin/main main` and
      `git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main` (no remote repository is needed);
   3. `git checkout -b feat/tax`, then with author and committer date set per commit:
      - `add tax.go` (2026-01-01T01:00:00Z): `internal/billing/tax.go` as in `billing`;
      - `add Rate and tax tests` (2026-01-01T22:00:00Z): `tax_test.go` and the `billing` `invoice_test.go`;
      - `wire tax into Total` (2026-01-02T00:00:00Z): the `billing` working-tree `invoice.go` with
        `ID    string` (no comment);
   4. uncommitted: `invoice.go` gets `ID    string // invoice number`, `web/src/price.ts` the `billing` edit,
      and `notes.md` stays untracked.
   Result (used by the scenarios and renders): merge-base `4ccefde`, HEAD `e325463`, commits `e325463`,
   `07cb52e`, `b5435c5`; Branch files `invoice.go +11 -2`, `invoice_test.go +20 -1`, `tax.go +41 -0`,
   `tax_test.go +33 -0`; Local `invoice.go +1 -1`, `price.ts +4 -4`, `notes.md`. The manifest lists these. The
   fake `gh` of `git-branch-base` answers pull request 482 (`baseRefName` `main`, `headRefName` `feat/tax`) or
   none; screen tests stub `branch.now()` at 2026-01-02T01:00:00Z (ages `1h`, `3h`, `1d`).
9. **State per repository.** `init.lua` keeps `M.state.by_root[root] = { tab, commit_view, folds }` next to
   `by_tab`. `changes.toggle` and the tab actions reopen on it; `changes.review` on a closed panel applies
   `first`. `M.reset()` clears it.
10. **Labels fit the left pane.** The left diff pane is about 26 columns next to a 35-column panel; the mock's
    `main · 1a2b3c4 (merge-base)` was cut to `<n · 4ccefde (merge-base)` in a real capture. Labels follow today's
    `<hash> · <name>` form: `4ccefde · main`, `e325463 · HEAD`; for a commit `07cb52e · parent` and
    `e325463 · <subject>` (the right pane is wider).

## Risks / Trade-offs

- [The first Cmd+G waits for base resolution] → only local git commands decide the tab; `gh` is never awaited.
  The wait has the integration budget; if the base fails, the panel opens on Local.
- [A huge branch] → the row cap and the Local tab's notification apply; commit files load lazily.
- [The hint float hides rows] → two virtual lines at the end of the buffer, and the scenario "Branch tab keeps
  the last row above the hint" pins it.
- [Render hashes depend on the fixture recipe] → the recipe is exact (Decision 8); a different hash means the
  fixture differs and the screen test says so.
- [`pr-comments-view` changes the strip] → the third pill is appended by that change and its renders show it;
  this change's renders show two pills.
- [Three main-spec scenarios move to this change's render] → "Changes panel matches the approved render" and
  "Changes panel with the diff view matches the approved render" now name "Proposed — Local only on main"; only
  the strip row is new, the tree rows are today's (compare Current).

## Renders

Approved mocks (lead's `prs/`): `r2_local` → "Proposed — Local tab", `r3_files_hint` → "Proposed — Branch tab,
files", `r3_commits_hint` → "Proposed — Branch tab, commits", `r3_main_hidden` → "Proposed — Local only on main".
Every render below is a real capture of today's config on the real fixture (scratch `capture.lua`, the same
tmux path as `make render`), with the panel columns and diff colours edited to the proposal, so text, line
numbers, stats and hashes are real. Differences from the mocks: no Comments pill and no `#482` in the
statusline (both `pr-comments-view`); no blank row under the strip (Decision 1); short diff labels (Decision 10);
no comment counts on file rows (`pr-comments-view`). Stand-ins: `◆` for devicons and the PR, commit and
"All changes" glyphs, `▾ ▸` expanders, `□` open folder, `⌘` is the real character. The `.ansi` copies with real
glyphs and colours are in `renders/` (`command cat renders/<name>.ansi`). New groups, unknown to
`make colorize` until this change defines them: `ChangesTabLocal`, `ChangesTabBranch`, `ChangesTabInactive`,
`ChangesBranchHeader`, `ChangesCommittedFile`, `ChangesCommitIcon`, `ChangesCommitHash`, `DiffViewCommitted`,
`DiffViewCommittedWord`, `DiffViewGutterCommitted`, `DiffViewArrowCommitted`.

**Current — changes panel**: `100x30`, Normal, `internal/billing/invoice.go` of the `billing` fixture (on `main`), `changes.toggle`, captured by `make render CASE=changes COLUMNS=100 LINES=30` before the diff debounce fired (`renders/current_changes.ansi`)

```text
                                     ◆ invoice.go                                                   
 ▾ ◪ Changes 5 files               ┃  1   package billing                                           
   ▾ □ internal/billing 4          ┃    1                                                           
     ▾ ☐ ◆ invoice.go       +12 -3 ┃    2 import (                                                  
         ☐ ◆ invoice_test.… +20 -1 ┃    3 ▏ "fmt"                                                   
     ▾ ☑ ◆ tax.go           +41 -0 ┃    4 ▏                                                         
         ☑ ◆ tax_test.go    +33 -0 ┃    5 ▏ "example.com/billing/internal/money"                    
   ▾ □ web/src 1                   ┃    6 )                                                         
       ☐ ◆ price.ts          +4 -4 ┃    7                                                           
 ▾ ☐ Unversioned Files 1 file      ┃    8 // Invoice is a list of line amounts in cents, with a tax 
     ☐ ◆ notes.md                  ┃    9 type Invoice struct {                                     
                                   ┃   10 ▏ ID    string // invoice number                          
                                   ┃   11 ▏ Lines []int                                             
                                   ┃   12 ▏ Tax   Rate                                              
                                   ┃   13 }                                                         
                                   ┃   14                                                           
                                   ┃   15 // Total sums the lines and applies the tax rate.         
                                   ┃   16 func (i Invoice) Total() int {                            
                                   ┃   17 ▏ var total int                                           
                                   ┃   18 ▏ for _, cents := range i.Lines {                         
                                   ┃   19 ▏ ▏ total += cents                                        
                                   ┃   20 ▏ }                                                       
                                   ┃   21 ▏ if i.Tax == nil {                                       
                                   ┃   22 ▏ ▏ return total                                          
                                   ┃   23 ▏ }                                                       
                                   ┃   24 ▏ return i.Tax.Apply(total)                               
                                   ┃   25 }                                                         
                                   ┃   26                                                           
                                   ┃   27 // Due renders the total as dollars.                      
 NORMAL                                                                   ◆ 0 ◆ 0 ◆ ◆ gleb-changes ◆
```

```text
....................................abaaaaaaaaaaaaaccccccccccccccccccccccccccccccccccccccccccccccccc
.d.d.eeeeeee.ddddddd...............f..gggghhhhhhh...................................................
...d.i..................d..........f..gggg..........................................................
jjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjf..gggghhhhhh....................................................
.........d.b.iiiiiiiiiiiiid.kkk.ll.f..ggggggmmmmm...................................................
.....d.d.b.kkkkkk...........kkk.ll.f..ggggg.........................................................
.........d.b.kkkkkkkkkkk....kkk.ll.f..ggggggmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm....................
...d.i.........d...................f..gggg..........................................................
.......d...iiiiiiii..........kk.ll.f..gggg..........................................................
.d.d.eeeeeeeeeeeeeeeee.dddddd......f..ggggnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn
.....d.o.pppppppp..................f..gggghhhh.qqqqqqq.hhhhhh.......................................
...................................f..ggggggqq....rrrrrr.nnnnnnnnnnnnnnnnn..........................
...................................f..ggggggqqqqq...rrr.............................................
...................................f..ggggggqqq...rrrr..............................................
...................................f..gggg..........................................................
...................................f..gggg..........................................................
...................................f..ggggnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn.........
...................................f..gggghhhh....rrrrrrr..sssss...rrr..............................
...................................f..gggggghhh.qqqqq.rrr...........................................
...................................f..gggggghhh.qm.qqqqq.hh.hhhhh.qmttttt...........................
...................................f..ggggggggqqqqq.hh.qqqqq........................................
...................................f..gggggg........................................................
...................................f..gggggghh.qmttt.hh.ttt.........................................
...................................f..gggggggghhhhhh.qqqqq..........................................
...................................f..gggggg........................................................
...................................f..gggggghhhhhh.qmtttmsssss.qqqqq................................
...................................f..gggg..........................................................
...................................f..gggg..........................................................
...................................f..ggggnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn......................
uuuuuuuuvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvwwwwwxxxxyzzzzzzzzzzzzzzzzA
```

Legend: `a` [BufferLineBufferSelected] · `b` [DevIconGo] · `c` [BufferLineFill] · `d` [ChangesCount] · `e` [ChangesRoot] · `f` [WinSeparator] · `g` [LineNr] · `h` [@keyword] · `i` [FileTreeFolderIcon] · `j` [FileTreeCursorLine] · `k` [ChangesStatAdded] · `l` [ChangesStatRemoved] · `m` [@string] · `n` [@comment] · `o` [DevIconMd] · `p` [FileTreeGitUntracked] · `q` [@type.definition] · `r` [@function.call] · `s` [@function] · `t` [@property] · `u` [lualine_a_normal] · `v` [lualine_b_normal] · `w` [lualine_x_diagnostics_error_command] · `x` [lualine_x_diagnostics_warn_command] · `y` [StatuslineLangCapError] · `z` [StatuslineLangText] · `A` [StatuslineLangEdge] · `.` [Normal]

**Proposed — Local tab**: `100x30`, Normal, `internal/billing/invoice.go` of the `billing-branch` fixture (branch `feat/tax`, PR #482), first `changes.review`; the panel is focused, the editor area shows the Local diff of `invoice.go`

```text
                                     ◆ invoice.go                                                   
  Local 3   Branch 4               ┃ e325463 · HEAD                           Your version          
 ▾ ☐ Changes 2 files               ┃~~ 6 unchanged lines ~~~~ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   ▾ □ internal/billing 1          ┃ )                           7        7   )                     
       ☐ ◆ invoice.go        +1 -1 ┃                             8        8                         
   ▾ □ web/src 1                   ┃ // Invoice is a list of     9        9   // Invoice is a list o
       ☐ ◆ price.ts          +4 -4 ┃ type Invoice struct {      10       10   type Invoice struct { 
 ▾ ☐ Unversioned Files 1 file      ┃   ID    string           » 11       11 ☐ ▏ ID    string // invo
     ☐ ◆ notes.md                  ┃   Lines []int              12       12   ▏ Lines []int         
                                   ┃   Tax   Rate               13       13   ▏ Tax   Rate          
                                   ┃ }                          14       14   }                     
                                   ┃                            15       15                         
                                   ┃~~ 22 unchanged lines ~~~ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                   ┃                                                                
                                   ┃                                                                
                                   ┃                                                                
                                   ┃                                                                
                                   ┃                                                                
                                   ┃                                                                
                                   ┃                                                                
                                   ┃                                                                
                                   ┃                                                                
                                   ┃                                                                
                                   ┃                                                                
                                   ┃                                                                
                                   ┃                                                                
                                   ┃                                                                
                                   ┃                                                                
                                   ┃                                                                
 NORMAL                                                                   ◆ 0 ◆ 0 ◆ ◆ gleb-changes ◆
```

```text
....................................abaaaaaaaaaaaaaccccccccccccccccccccccccccccccccccccccccccccccccc
.ddddddddd.eeeeeeeeee..............fggggggggggggggggggggggggg.gggggggggggggggggggggggggggggggggggggg
.h.h.iiiiiii.hhhhhhh...............fjjkkkkkkkkkkkkkkkkkkkjjjjljjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj
...h.m..................h..........f.........................l.kkkk.....kkkk........................
nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnf.........................l.kkkk.....kkkk........................
...h.m.........h...................f.ooooooooooooooooooooooool.kkkk.....kkkk..oooooooooooooooooooooo
.......h...mmmmmmmm..........pp.qq.f.rrrr.sssssss.rrrrrr.....l.kkkk.....kkkk..rrrr.sssssss.rrrrrr...
.h.h.iiiiiiiiiiiiiiiii.hhhhhh......ftttttttttttttttttttttttttluvvvvtttttvvvvvvttttttttttttttwooooooo
.....h.x.yyyyyyyy..................f...sssss...zzz...........l.kkkk.....kkkk..jjsssss...zzz.........
...................................f...sss...zzzz............l.kkkk.....kkkk..jjsss...zzzz..........
...................................f.........................l.kkkk.....kkkk........................
...................................f.........................l.kkkk.....kkkk........................
...................................fjjkkkkkkkkkkkkkkkkkkkkjjjljjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj
...................................f.........................l......................................
...................................f.........................l......................................
...................................f.........................l......................................
...................................f.........................l......................................
...................................f.........................l......................................
...................................f.........................l......................................
...................................f.........................l......................................
...................................f.........................l......................................
...................................f.........................l......................................
...................................f.........................l......................................
...................................f.........................l......................................
...................................f.........................l......................................
...................................f.........................l......................................
...................................f.........................l......................................
...................................f.........................l......................................
...................................f.........................l......................................
AAAAAAAABBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBCCCCCDDDDEFFFFFFFFFFFFFFFFG
```

Legend: `a` [BufferLineBufferSelected] · `b` [DevIconGo] · `c` [BufferLineFill] · `d` [ChangesTabLocal] · `e` [ChangesTabInactive] · `f` [WinSeparator] · `g` [DiffViewHeader] · `h` [ChangesCount] · `i` [ChangesRoot] · `j` [DiffViewFold] · `k` [DiffViewLineNr] · `l` [DiffViewPadding] · `m` [FileTreeFolderIcon] · `n` [FileTreeCursorLine] · `o` [@comment] · `p` [ChangesStatAdded] · `q` [ChangesStatRemoved] · `r` [@keyword] · `s` [@type.definition] · `t` [DiffViewChange] · `u` [DiffViewArrowChange] · `v` [DiffViewGutterChange] · `w` [DiffViewWord] · `x` [DevIconMd] · `y` [FileTreeGitUntracked] · `z` [@function.call] · `A` [lualine_a_normal] · `B` [lualine_b_normal] · `C` [lualine_x_diagnostics_error_command] · `D` [lualine_x_diagnostics_warn_command] · `E` [StatuslineLangCapError] · `F` [StatuslineLangText] · `G` [StatuslineLangEdge] · `.` [Normal]

**Proposed — Branch tab, files**: `100x30`, Normal, `billing-branch` fixture, second `changes.review`; cursor on `invoice.go`, the editor area shows the read-only merge-base diff of `invoice.go`

```text
                                     ◆ invoice.go                                                   
  Local 3   Branch 4               ┃ 4ccefde · main                           e325463 · HEAD        
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
 NORMAL                                                                   ◆ 0 ◆ 0 ◆ ◆ gleb-changes ◆
```

```text
....................................abbaaaaaaaaaaaaccccccccccccccccccccccccccccccccccccccccccccccccc
.ddddddddd.eeeeeeeeee..............fgggggggggggggggggggggggggfgggggggggggggggggggggggggggggggggggggg
.hhhhhhiiiiiiiiiiiiiiii............fjjkkkkkkkkkkkkkkkkkkkjjjjljjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj
.iiiiiiiiiiiiiiiiiiiiiiiiiiiiii....f.........................l.kkkk.....kkkk........................
...................................f...mmmmmmmmmmmmmmmmmmmmmml.kkkk.....kkkk........................
.n.o.pppppppppppppppp.i............f.........................l.kkkk.....kkkk........................
qqqnqbqrrrrrrrrrrqqqqqqqqqqqsssqttqf.........................l.kkkk.....kkkk........................
.......b.rrrrrrrrrrrrrrr....sss.tt.fuvvvvvvvvvvvvvvvvvvvvvvvvlwxxxxuuuuuxxxxxxuuuuuuuuuuuuuuuuuuuuuu
...n.b.rrrrrr...............sss.tt.f.yyyy.zzzzzzz.yyyyyy.....l.kkkk.....kkkk........................
.......b.rrrrrrrrrrr........sss.tt.f...zz....AAAAAA..........l.kkkk.....kkkk........................
...................................f...zzzzz...AAA...........l.kkkk.....kkkk........................
...................................f...zzz...AAAA............l.kkkk.....kkkk........................
...................................f.........................l.kkkk.....kkkk........................
...................................f.........................l.kkkk.....kkkk........................
...................................f.vvvvvvvvvvvvvvvvvvvvvvvvl.kkkk.....kkkk........................
...................................f.yyyy....AAAAAAA..BBBBB..l.kkkk.....kkkk........................
...................................fuuuuuuuuuCCCCuuuuuuuuuuuulwxxxxuuuuuxxxxxxuuCCCCuuuuuuCCCuuuuuuu
...................................f...yyy.zm.zzzzz.yy.yyyyy.l.kkkk.....kkkk........................
...................................f.....zzzzz.yy.zzzzz......l.kkkk.....kkkk........................
...................................f.........................l.kkkk.....kkkk........................
...................................fllllllllllllllllllllllllllwlllluuuuuxxxxxxuuuuuuuuuuuuuuuuuuuuuu
...................................fllllllllllllllllllllllllll.lllluuuuuxxxxxxuuuuuuuuuuuuuuuuuuuuuu
...................................fllllllllllllllllllllllllll.lllluuuuuxxxxxxuuuuuuuuuuuuuuuuuuuuuu
...................................f...yyyyyy.zmDDDmBBBBB.zzzl.kkkk.....kkkk........................
...................................f.........................l.kkkk.....kkkk........................
...................................f.........................l.kkkk.....kkkk........................
...................................f.vvvvvvvvvvvvvvvvvvvvvvvvl.kkkk.....kkkk........................
EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEf.yyyy....AAAAAAA..BBB...Al.kkkk.....kkkk........................
...........FFFFFFFFFFFFFFFFFFFFFFF.f...yyyyyy.zzzmBBBBBBB.mmml.kkkk.....kkkk........................
GGGGGGGGHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHIIIIIJJJJKLLLLLLLLLLLLLLLLM
```

Legend: `a` [BufferLineBackground] · `b` [DevIconGo] · `c` [BufferLineFill] · `d` [ChangesTabInactive] · `e` [ChangesTabBranch] · `f` [WinSeparator] · `g` [DiffViewHeader] · `h` [ChangesBranchHeader] · `i` [ChangesCount] · `j` [DiffViewFold] · `k` [DiffViewLineNr] · `l` [DiffViewPadding] · `m` [@string] · `n` [FileTreeExpander] · `o` [FileTreeFolderIcon] · `p` [FileTreeFolderName] · `q` [FileTreeCursorLine] · `r` [ChangesCommittedFile] · `s` [ChangesStatAdded] · `t` [ChangesStatRemoved] · `u` [DiffViewCommitted] · `v` [@comment] · `w` [DiffViewArrowCommitted] · `x` [DiffViewGutterCommitted] · `y` [@keyword] · `z` [@type.definition] · `A` [@function.call] · `B` [@function] · `C` [DiffViewCommittedWord] · `D` [@property] · `E` [PickerBorder] · `F` [PickerHint] · `G` [lualine_a_normal] · `H` [lualine_b_normal] · `I` [lualine_x_diagnostics_error_command] · `J` [lualine_x_diagnostics_warn_command] · `K` [StatuslineLangCapError] · `L` [StatuslineLangText] · `M` [StatuslineLangEdge] · `.` [Normal]

**Proposed — Branch tab, commits**: `100x30`, Normal, `billing-branch` fixture, Branch tab after `c`; newest commit expanded, cursor on its `invoice.go`, the editor area shows that commit's diff

```text
                                     ◆ invoice.go                                                   
  Local 3   Branch 4               ┃ 07cb52e · parent                         e325463 · wire tax int
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
 NORMAL                                                                   ◆ 0 ◆ 0 ◆ ◆ gleb-changes ◆
```

```text
....................................abbaaaaaaaaaaaaccccccccccccccccccccccccccccccccccccccccccccccccc
.ddddddddd.eeeeeeeeee..............fgggggggggggggggggggggggggfgggggggggggggggggggggggggggggggggggggg
.hhhhhhiiiiiiiiiiiiiiii............fjjkkkkkkkkkkkkkkkkkkkjjjjljjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj
...................................f.........................l.kkkk.....kkkk........................
.m.n.ooooooooooo...........iiiiiii.f...ppppppppppppppppppppppl.kkkk.....kkkk........................
.m.n.qqqqqqq.rrrrrrrrrrrrrrrrri.ii.f.........................l.kkkk.....kkkk........................
sssssbsttttttttttsssssssssssuuusvvsf.........................l.kkkk.....kkkk........................
.m.n.qqqqqqq.rrrrrrrrrrrrrrrrri.ii.fwxxxxxxxxxxxxxxxxxxxxxxxxlyzzzzwwwwwzzzzzzwwwwwwwwwwwwwwwwwwwwww
.m.n.qqqqqqq.rrrrrrrrrr.........ii.f.AAAA.BBBBBBB.AAAAAA.....l.kkkk.....kkkk........................
...................................f...BB....CCCCCC..........l.kkkk.....kkkk........................
...................................f...BBBBB...CCC...........l.kkkk.....kkkk........................
...................................f...BBB...CCCC............l.kkkk.....kkkk........................
...................................f.........................l.kkkk.....kkkk........................
...................................f.........................l.kkkk.....kkkk........................
...................................f.xxxxxxxxxxxxxxxxxxxxxxxxl.kkkk.....kkkk........................
...................................f.AAAA....CCCCCCC..DDDDD..l.kkkk.....kkkk........................
...................................fwwwwwwwwwEEEEwwwwwwwwwwwwlyzzzzwwwwwzzzzzzwwEEEEwwwwwwEEEwwwwwww
...................................f...AAA.Bp.BBBBB.AA.AAAAA.l.kkkk.....kkkk........................
...................................f.....BBBBB.AA.BBBBB......l.kkkk.....kkkk........................
...................................f.........................l.kkkk.....kkkk........................
...................................fllllllllllllllllllllllllllyllllwwwwwzzzzzzwwwwwwwwwwwwwwwwwwwwww
...................................fllllllllllllllllllllllllll.llllwwwwwzzzzzzwwwwwwwwwwwwwwwwwwwwww
...................................fllllllllllllllllllllllllll.llllwwwwwzzzzzzwwwwwwwwwwwwwwwwwwwwww
...................................f...AAAAAA.BpFFFpDDDDD.BBBl.kkkk.....kkkk........................
...................................f.........................l.kkkk.....kkkk........................
...................................f.........................l.kkkk.....kkkk........................
...................................f.xxxxxxxxxxxxxxxxxxxxxxxxl.kkkk.....kkkk........................
GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGf.AAAA....CCCCCCC..DDD...Cl.kkkk.....kkkk........................
.............HHHHHHHHHHHHHHHHHHHHH.f...AAAAAA.BBBpDDDDDDD.pppl.kkkk.....kkkk........................
IIIIIIIIJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJKKKKKLLLLMNNNNNNNNNNNNNNNNO
```

Legend: `a` [BufferLineBackground] · `b` [DevIconGo] · `c` [BufferLineFill] · `d` [ChangesTabInactive] · `e` [ChangesTabBranch] · `f` [WinSeparator] · `g` [DiffViewHeader] · `h` [ChangesBranchHeader] · `i` [ChangesCount] · `j` [DiffViewFold] · `k` [DiffViewLineNr] · `l` [DiffViewPadding] · `m` [FileTreeExpander] · `n` [ChangesCommitIcon] · `o` [ChangesRoot] · `p` [@string] · `q` [ChangesCommitHash] · `r` [FileTreeFileName] · `s` [FileTreeCursorLine] · `t` [ChangesCommittedFile] · `u` [ChangesStatAdded] · `v` [ChangesStatRemoved] · `w` [DiffViewCommitted] · `x` [@comment] · `y` [DiffViewArrowCommitted] · `z` [DiffViewGutterCommitted] · `A` [@keyword] · `B` [@type.definition] · `C` [@function.call] · `D` [@function] · `E` [DiffViewCommittedWord] · `F` [@property] · `G` [PickerBorder] · `H` [PickerHint] · `I` [lualine_a_normal] · `J` [lualine_b_normal] · `K` [lualine_x_diagnostics_error_command] · `L` [lualine_x_diagnostics_warn_command] · `M` [StatuslineLangCapError] · `N` [StatuslineLangText] · `O` [StatuslineLangEdge] · `.` [Normal]

**Proposed — Local only on main**: `100x30`, Normal, `internal/billing/invoice.go` of the `billing` fixture (on `main`, no base), first `changes.review`; no Branch tab

```text
                                     ◆ invoice.go                                                   
  Local 6                          ┃ 4ccefde · HEAD                           Your version          
 ▾ ◪ Changes 5 files               ┃~~ 4 unchanged lines ~~~~ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   ▾ □ internal/billing 4          ┃                             5        5   ▏                     
     ▾ ☐ ◆ invoice.go       +12 -3 ┃   "example.com/billing/i    6        6   ▏ "example.com/billing
         ☐ ◆ invoice_test.… +20 -1 ┃ )                           7        7   )                     
     ▾ ☑ ◆ tax.go           +41 -0 ┃                             8        8                         
         ☑ ◆ tax_test.go    +33 -0 ┃ // Invoice is a list of  »  9        9 ☐ // Invoice is a list o
   ▾ □ web/src 1                   ┃ type Invoice struct {      10       10   type Invoice struct { 
       ☐ ◆ price.ts          +4 -4 ┃   ID    string           » 11       11 ☐ ▏ ID    string // invo
 ▾ ☐ Unversioned Files 1 file      ┃   Lines []int              12       12   ▏ Lines []int         
     ☐ ◆ notes.md                  ┃   Tax   Rate               13       13   ▏ Tax   Rate          
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
.ddddddddd.........................efffffffffffffffffffffffff.ffffffffffffffffffffffffffffffffffffff
.g.g.hhhhhhh.ggggggg...............eiijjjjjjjjjjjjjjjjjjjiiiikiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
...g.l..................g..........e.........................k.jjjj.....jjjj..i.....................
mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmme...nnnnnnnnnnnnnnnnnnnnnnk.jjjj.....jjjj..iinnnnnnnnnnnnnnnnnnnn
.........g.b.lllllllllllllg.ooo.pp.e.........................k.jjjj.....jjjj........................
.....g.g.b.oooooo...........ooo.pp.e.........................k.jjjj.....jjjj........................
.........g.b.ooooooooooo....ooo.pp.eqrrrrrrrrrrrrrrrrrrrrrrrrksttttqqqqqttttttrrrrrrrrrrrrrrrrrrrrrr
...g.l.........g...................e.uuuu.vvvvvvv.uuuuuu.....k.jjjj.....jjjj..uuuu.vvvvvvv.uuuuuu...
.......g...llllllll..........oo.pp.eqqqqqqqqqqqqqqqqqqqqqqqqqksttttqqqqqttttttqqqqqqqqqqqqqqwrrrrrrr
.g.g.hhhhhhhhhhhhhhhhh.gggggg......e...vvvvv...xxx...........k.jjjj.....jjjj..iivvvvv...xxx.........
.....g.y.zzzzzzzz..................e...vvv...xxxx............k.jjjj.....jjjj..iivvv...xxxx..........
...................................e.........................k.jjjj.....jjjj........................
...................................e.........................k.jjjj.....jjjj........................
...................................e.rrrrrrrrrrrrrrrrrrrrrrrrk.jjjj.....jjjj..rrrrrrrrrrrrrrrrrrrrrr
...................................e.uuuu....xxxxxxx..AAAAA..k.jjjj.....jjjj..uuuu....xxxxxxx..AAAAA
...................................eqqqqqqqqqwwwwqqqqqqqqqqqqksttttqqqqqttttttqqwwwwqqqqqqwwwqqqqqqq
...................................e...uuu.vn.vvvvv.uu.uuuuu.k.jjjj.....jjjj..iiuuu.vn.vvvvv.uu.uuuu
...................................e.....vvvvv.uu.vvvvv......k.jjjj.....jjjj..iiiivvvvv.uu.vvvvv....
...................................e.........................k.jjjj.....jjjj..ii....................
...................................ekkkkkkkkkkkkkkkkkkkkkkkkkkBkkkkCCCCCDDDDDDCCCCCCCCCCCCCCCCCCCCCC
...................................ekkkkkkkkkkkkkkkkkkkkkkkkkk.kkkkCCCCCDDDDDDCCCCCCCCCCCCCCCCCCCCCC
...................................ekkkkkkkkkkkkkkkkkkkkkkkkkk.kkkkCCCCCDDDDDDCCCCCCCCCCCCCCCCCCCCCC
...................................e...uuuuuu.vnEEEnAAAAA.vvvk.jjjj.....jjjj..iiuuuuuu.vnEEEnAAAAA.v
...................................e.........................k.jjjj.....jjjj........................
...................................e.........................k.jjjj.....jjjj........................
...................................e.rrrrrrrrrrrrrrrrrrrrrrrrk.jjjj.....jjjj..rrrrrrrrrrrrrrrrrrrrrr
...................................e.uuuu....xxxxxxx..AAA...xk.jjjj.....jjjj..uuuu....xxxxxxx..AAA..
...................................e...uuuuuu.vvvnAAAAAAA.nnnk.jjjj.....jjjj..iiuuuuuu.vvvnAAAAAAA.n
FFFFFFFFGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGHHHHHIIIIJKKKKKKKKKKKKKKKKL
```

Legend: `a` [BufferLineBufferSelected] · `b` [DevIconGo] · `c` [BufferLineFill] · `d` [ChangesTabLocal] · `e` [WinSeparator] · `f` [DiffViewHeader] · `g` [ChangesCount] · `h` [ChangesRoot] · `i` [DiffViewFold] · `j` [DiffViewLineNr] · `k` [DiffViewPadding] · `l` [FileTreeFolderIcon] · `m` [FileTreeCursorLine] · `n` [@string] · `o` [ChangesStatAdded] · `p` [ChangesStatRemoved] · `q` [DiffViewChange] · `r` [@comment] · `s` [DiffViewArrowChange] · `t` [DiffViewGutterChange] · `u` [@keyword] · `v` [@type.definition] · `w` [DiffViewWord] · `x` [@function.call] · `y` [DevIconMd] · `z` [FileTreeGitUntracked] · `A` [@function] · `B` [DiffViewArrowAdd] · `C` [DiffViewAdd] · `D` [DiffViewGutterAdd] · `E` [@property] · `F` [lualine_a_normal] · `G` [lualine_b_normal] · `H` [lualine_x_diagnostics_error_command] · `I` [lualine_x_diagnostics_warn_command] · `J` [StatuslineLangCapError] · `K` [StatuslineLangText] · `L` [StatuslineLangEdge] · `.` [Normal]
