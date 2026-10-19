## Context

The user wants the branch's committed changes in purple next to the uncommitted ones (decision page,
2026-10-19: P1 colour gruvbox purple `#d3869b`, P2 "purple layer always on, on a branch with a base").
`git-branch-base` gives the merge-base of the current branch. This change draws the merge-base → HEAD
layer in the gutter.

Today:

- gitsigns (`lua/gleb/git/gitsigns.lua`) draws index → buffer hunks with `┃` and a Nerd Font delete glyph, as
  extmark signs at gitsigns' default priority 6, staged and unstaged alike.
- `signcolumn = "yes"` (`options.lua`) is one cell wide, so only the highest-priority sign of a line is drawn.
- The owned diff view sets `signcolumn = "no"` in its windows (`diff/view/windows.lua`), so buffer signs never
  show there.

Plugins that could draw a second git layer were checked (2026-10-19):

- gitsigns has one base per buffer: `:Gitsigns change_base` replaces the local layer, it does not add one;
- mini.diff has one reference text per buffer, and the git spec forbids it next to gitsigns;
- diffview has no gutter.

No maintained plugin draws two git bases at once, so this is a small owned extmark layer built on the
built-in `vim.text.diff` (xdiff).

## Goals / Non-Goals

**Goals:**
- Every line committed on the branch since the merge-base shows a purple sign in every normal file buffer of
  the repository. This holds through unsaved edits, and an uncommitted change on the same line shows its
  gitsigns sign instead.
- No base: no sign, no work.
- Bounded cost:
  - two `git cat-file` calls per file that changed on the branch, for each new merge-base/HEAD pair;
  - one in-memory diff per debounced edit;
  - nothing for files the branch did not change.

**Non-Goals:**
- Purple in the diff view or in the changes panel (`git-changes-tabs`).
- Hunk actions on committed hunks (stage, reset, preview).
- A toggle. The user wants the layer always on.

## Decisions

1. **Module.** `lua/gleb/git/committed_signs/map.lua` (pure: hunks, kinds, head → buffer mapping) and
   `lua/gleb/git/committed_signs/init.lua` (buffer attach, git reads, extmarks, highlight).
   `lua/gleb/git/init.lua` requires `gleb.git.committed_signs` right after `gleb.git.gitsigns` (rule 1.6, with
   a comment: the layer sits under gitsigns' signs). Its `setup` only creates the augroup
   `gleb_git_committed_signs` and the highlight, so startup runs no git.
2. **Sign texts are shared.** A new `lua/gleb/git/sign_text.lua` returns `{ bar = "┃", delete = <the Nerd
   Font glyph gitsigns.lua uses today> }`. `gitsigns.lua` reads its texts from it, so both layers draw the
   same shapes (rule 9.5: never empty).
3. **Kinds**, gitsigns' semantics: `map.kinds(base_lines, head_lines)` diffs with
   `vim.text.diff(…, { result_type = "indices", algorithm = "myers", indent_heuristic = true })`, the same
   hunks as `git diff`, so the fixture manifest computed by `git diff -U0` matches. For each hunk
   `{a_start, a_count, b_start, b_count}`:
   - `b_count == 0` is a `delete` on head line `b_start` (`topdelete` on line 1 when `b_start == 0`);
   - `a_count == 0` is an `add` on head lines `b_start … b_start + b_count - 1`;
   - otherwise those lines are a `change`, and the last one is a `changedelete` when `a_count > b_count`.

   Signs: `bar` for add, change and changedelete; `delete` for delete and topdelete. All use
   `GitCommittedSign`.
4. **Mapping onto the live buffer.** `map.to_buffer(head_lines, buf_lines, kinds)` diffs HEAD against the
   current buffer lines (unsaved edits included) with the same options.
   - A kinded head line inside a local hunk's head range (`a_count > 0`) is dropped: the line changed
     locally, and gitsigns marks it.
   - Every other kinded line moves by the sum of `b_count - a_count` over the local hunks that end before
     it. A pure insertion (`a_count == 0`) after head line `a_start` moves the lines after `a_start`.

   Verified examples (Neovim 0.12.5, `nvim --clean -l`), the unit table:

   | base | head | buffer | committed kinds (head) | signs (buffer) |
   |---|---|---|---|---|
   | `a b c d` | `a B c x d` | = head | 2 change, 4 add | 2 change, 4 add |
   | `a b c d` | `a d` | = head | 1 delete | 1 delete |
   | `a b` | `b` | = head | 1 topdelete | 1 topdelete |
   | `a b c d` | `a X d` | = head | 2 changedelete | 2 changedelete |
   | `a b c d` | `a B c x d` | `new a B c x d` | 2 change, 4 add | 3 change, 5 add |
   | `a b c d` | `a B c x d` | `a B2 c x d` | 2 change, 4 add | 4 add |
   | `a b c d` | `a B c x d` | `a B x d` | 2 change, 4 add | 2 change, 3 add |
   | `a b c d` | `a B c x d` | `a B c x d tail` | 2 change, 4 add | 2 change, 4 add |

   Performance: 10 000 lines with one committed change and one local insertion take 1.3 ms for kinds plus
   mapping. The bound in the spec is 50 ms, scaled by `H.load_factor()`.
5. **Which files, and their text.**
   - Per root, per `(merge_base, head)`: `git diff --name-status -z -M --no-ext-diff <merge_base> <head>`
     gives the files changed on the branch. For `R`/`C` the base path is the old path, for `A` there is no
     base text. Anything not in the list gets no sign and no further git call.
   - For a listed file the texts come from `git cat-file blob <merge_base>:<base_path>` and
     `git cat-file blob <head>:<path>`. Oids are used, not `HEAD`, so a commit during the read cannot mix
     revisions. They are cached on the buffer with their key `(merge_base, head, base_path)`.
   - The file is skipped when either blob has a NUL byte in its first 8000 bytes (binary, git's rule), is
     larger than `MAX_BYTES = 2 MiB`, or has more than `MAX_LINES = 20000` lines.
   - Both limits are `UPPER_SNAKE` constants exported on `M` for tests.
6. **Triggers.**
   - `BufEnter`/`BufReadPost` of a buffer with `buftype == ""` and a readable file name: `base.resolve(path)`,
     which answers from the cache in steady state. With an Info and a listed file, the buffer is attached once
     with `nvim_buf_attach(buf, false, { on_lines, on_reload, on_detach })`.
   - `on_lines`/`on_reload`: a per-buffer `DEBOUNCE_MS = 150` timer re-runs only Decision 4. The committed
     kinds stay cached.
   - `User GlebGitBaseChanged` with `data.root`: every attached buffer under the root recomputes. A nil Info
     clears the namespace in them.
   - `BufWipeout`/`on_detach`: the buffer's state and timer are dropped (rule 6.5). Async results check that
     the buffer is valid and their key is still current (rule 6.3).
7. **Extmarks.**
   - Namespace `gleb_git_committed_signs`, priority `SIGN_PRIORITY = 5`, one below gitsigns' default 6.
   - Each update clears the namespace and sets one extmark per signed line:
     `{ sign_text = …, sign_hl_group = "GitCommittedSign", priority = 5 }`. No number, line or culhl
     highlight.
   - The diff view's `signcolumn = "no"` hides them there, as it hides gitsigns.
8. **Colour.** `GitCommittedSign` = `{ fg = palette.foreground.purple }` (`#d3869b`, rule 8.7). It is set in
   setup and again on `ColorScheme`, like `changes/highlights.lua`. The other purple groups of PR_PLAN
   (`DiffViewCommitted*`, `ChangesCommittedFile`) belong to `git-changes-tabs`.
9. **Fixtures and repos.**
   - The `prbranch` fixture of `git-branch-base` (design.md, Fixture) drives the integration and screen cases.
   - The deletion and rename cases build a branch repo in the case: `H.git_repo(files)` on `main`, then
     `git update-ref refs/remotes/origin/main HEAD`, `git symbolic-ref refs/remotes/origin/HEAD
     refs/remotes/origin/main`, `git checkout -q -b feat/x`, and one commit:
     - deletion: `lib/util.lua` with lines `local M = {}`, `M.a = 1`, `M.b = 2`, `M.c = 3`, `return M`; the
       commit removes `M.b = 2` and `M.c = 3`, so line 2 (`M.a = 1`) gets the delete glyph and no other
       line has a sign. Topdelete is covered by the unit table.
     - rename: `git mv lib/util.lua lib/helpers.lua` plus `M.a = 1` → `M.a = 10`, so only line 2 is marked.
   - The `gh` stub of `git-branch-base` answers "no pull request" in every case.
10. **Render case.** `tests/render/cases.lua` gains `committed-signs`: a fresh `prbranch` copy, gopls,
    null-ls and diagnostics off, `internal/billing/invoice.go` opened, waiting for the gitsigns hunk and
    the committed extmarks. `make render CASE=committed-signs COLUMNS=100 LINES=30` then reproduces
    Proposed. The Current B capture used the same setup from a scratch case file.

## Renders

The real captures and the Proposed composite are also in `renders/` as truecolor `.ansi` (`less -R`). Proposed
is Current B with the five committed signs set, the editor part of the approved `pr_colour_gruvbox` /
`pr_gutter` mocks. The mocks' left panel (the superseded two-roots idea) and the `#482` statusline chip
belong to `git-changes-tabs` and `pr-comments-view`, so they are not drawn here. `make colorize` on this file
reports only `GitCommittedSign` as unknown.

**Current A — gutter today**: `100x30`, Normal, `git-hunk` render case (`sample.lua` in a temp repo on `main`, line 2 added, no LSP), cursor on line 1 (real capture, `make render CASE=git-hunk`).

```text
▎     ◆ sample.lua                                                                                  
  1   local M = {}                                                                                  
┃   1 M.x = 1                                                                                       
    2                                                                                               
    3 return M                                                                                      
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
 NORMAL  ⎇ main  ◆ 1                                                               ◆ 0 ◆ 0 ◆ ◆ lua ◆
```

```text
abbbbbccbbbbbbbbbbbbbbbbdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
..e...fffff.g.h.ii..................................................................................
j...e.gkl.h.m.......................................................................................
....e...............................................................................................
....e.nnnnnn.g......................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
ooooooooppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppqqqqqrrrrstuttttts
```

Legend: `a` [BufferLineIndicatorSelected] · `b` [BufferLineBufferSelected] · `c` [BufferLineDevIconLuaSelected] · `d` [BufferLineFill] · `e` [LineNr] · `f` [@keyword] · `g` [@constant] · `h` [@operator] · `i` [@punctuation.bracket] · `j` [GitSignsAdd] · `k` [@punctuation.delimiter] · `l` [@variable.member] · `m` [@number] · `n` [@keyword.return] · `o` [lualine_a_normal] · `p` [BufferLineBufferVisible] · `q` [lualine_x_diagnostics_error_normal] · `r` [lualine_x_diagnostics_warn_normal] · `s` [CursorLine] · `t` [StatuslineLangText] · `u` [StatuslineLang_lua] · `.` [Normal]

**Current B — committed lines are invisible today**: `100x30`, Normal, `prbranch` fixture (branch `feat/tax`, 3 commits over its merge-base with `origin/main`, line 11 changed in the working tree), `internal/billing/invoice.go`, LSP and diagnostics off, cursor on line 1 (real capture through a scratch render case with the same setup as the screen test). Only the uncommitted line 11 has a sign.

```text
▎     ◆ invoice.go                                                                                  
  1   package billing                                                                               
    1                                                                                               
    2 import (                                                                                      
    3 ▏ "fmt"                                                                                       
    4 ▏                                                                                             
    5 ▏ "example.com/billing/internal/money"                                                        
    6 )                                                                                             
    7                                                                                               
    8 // Invoice is a list of line amounts in cents.                                                
    9 type Invoice struct {                                                                         
┃  10 ▏ ID    string // invoice number                                                              
   11 ▏ Lines []int                                                                                 
   12 ▏ Tax   Rate                                                                                  
   13 }                                                                                             
   14                                                                                               
   15 // Total sums the lines and applies the tax rate.                                             
   16 func (i Invoice) Total() int {                                                                
   17 ▏ var total int                                                                               
   18 ▏ for _, cents := range i.Lines {                                                             
   19 ▏ ▏ total += cents                                                                            
   20 ▏ }                                                                                           
   21 ▏ if i.Tax == nil {                                                                           
   22 ▏ ▏ return total                                                                              
   23 ▏ }                                                                                           
   24 ▏ return i.Tax.Apply(total)                                                                   
   25 }                                                                                             
   26                                                                                               
   27 // Due renders the total as dollars.                                                          
 NORMAL  ⎇ feat/tax  ◆ 1                                                            ◆ 0 ◆ 0 ◆ ◆ go ◆
```

```text
abbbbbccbbbbbbbbbbbbbbbbdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
..e...fffffff.......................................................................................
....e...............................................................................................
....e.ffffff.g......................................................................................
....e.h.iiiii.......................................................................................
....e.h.............................................................................................
....e.h.iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii........................................................
....e.g.............................................................................................
....e...............................................................................................
....e.jj.jjjjjjj.jj.j.jjjj.jj.jjjj.jjjjjjj.jj.jjjjjj................................................
....e.kkkk.lllllll.kkkkkk.g.........................................................................
m..ee.h.nn....oooooo.jj.jjjjjjj.jjjjjj..............................................................
...ee.h.nnnnn.ggooo.................................................................................
...ee.h.nnn...pppp..................................................................................
...ee.g.............................................................................................
...ee...............................................................................................
...ee.jj.jjjjj.jjjj.jjj.jjjjj.jjj.jjjjjjj.jjj.jjj.jjjjj.............................................
...ee.qqqq.gr.pppppppg.sssssgg.ooo.g................................................................
...ee.h.kkk.ttttt.ooo...............................................................................
...ee.h.uuu.tv.ttttt.ww.kkkkk.tvxxxxx.g.............................................................
...ee.h.h.ttttt.ww.ttttt............................................................................
...ee.h.g...........................................................................................
...ee.h.yy.tvxxx.ww.zzz.g...........................................................................
...ee.h.h.AAAAAA.ttttt..............................................................................
...ee.h.g...........................................................................................
...ee.h.AAAAAA.tvxxxvBBBBBgtttttg...................................................................
...ee.g.............................................................................................
...ee...............................................................................................
...ee.jj.jjj.jjjjjjj.jjj.jjjjj.jj.jjjjjjjj..........................................................
CCCCCCCCDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDEEEEEFFFFGHcHHHHG
```

Legend: `a` [BufferLineIndicatorSelected] · `b` [BufferLineBufferSelected] · `c` [DevIconGo] · `d` [BufferLineFill] · `e` [LineNr] · `f` [@keyword.import] · `g` [@punctuation.bracket] · `h` [IblIndent] · `i` [@string] · `j` [@comment] · `k` [@keyword] · `l` [@type.definition] · `m` [GitSignsChange] · `n` [@variable.member] · `o` [@type.builtin] · `p` [@type] · `q` [@keyword.function] · `r` [@variable.parameter] · `s` [@function.method] · `t` [@variable] · `u` [@keyword.repeat] · `v` [@punctuation.delimiter] · `w` [@operator] · `x` [@property] · `y` [@keyword.conditional] · `z` [@character] · `A` [@keyword.return] · `B` [@function.method.call] · `C` [lualine_a_normal] · `D` [BufferLineBufferVisible] · `E` [lualine_x_diagnostics_error_normal] · `F` [lualine_x_diagnostics_warn_normal] · `G` [CursorLine] · `H` [StatuslineLangText] · `.` [Normal]

**Proposed — committed signs** (approved `pr_colour_gruvbox` / `pr_gutter`, editor part): `100x30`, same state as Current B. The lines committed on `feat/tax` since the merge-base (13, 18, 22-24) carry a purple `┃` [GitCommittedSign]; the uncommitted line 11 keeps its gitsigns [GitSignsChange] bar.

```text
▎     ◆ invoice.go                                                                                  
  1   package billing                                                                               
    1                                                                                               
    2 import (                                                                                      
    3 ▏ "fmt"                                                                                       
    4 ▏                                                                                             
    5 ▏ "example.com/billing/internal/money"                                                        
    6 )                                                                                             
    7                                                                                               
    8 // Invoice is a list of line amounts in cents.                                                
    9 type Invoice struct {                                                                         
┃  10 ▏ ID    string // invoice number                                                              
   11 ▏ Lines []int                                                                                 
┃  12 ▏ Tax   Rate                                                                                  
   13 }                                                                                             
   14                                                                                               
   15 // Total sums the lines and applies the tax rate.                                             
   16 func (i Invoice) Total() int {                                                                
┃  17 ▏ var total int                                                                               
   18 ▏ for _, cents := range i.Lines {                                                             
   19 ▏ ▏ total += cents                                                                            
   20 ▏ }                                                                                           
┃  21 ▏ if i.Tax == nil {                                                                           
┃  22 ▏ ▏ return total                                                                              
┃  23 ▏ }                                                                                           
   24 ▏ return i.Tax.Apply(total)                                                                   
   25 }                                                                                             
   26                                                                                               
   27 // Due renders the total as dollars.                                                          
 NORMAL  ⎇ feat/tax  ◆ 1                                                            ◆ 0 ◆ 0 ◆ ◆ go ◆
```

```text
abbbbbccbbbbbbbbbbbbbbbbdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
..e...fffffff.......................................................................................
....e...............................................................................................
....e.ffffff.g......................................................................................
....e.h.iiiii.......................................................................................
....e.h.............................................................................................
....e.h.iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii........................................................
....e.g.............................................................................................
....e...............................................................................................
....e.jj.jjjjjjj.jj.j.jjjj.jj.jjjj.jjjjjjj.jj.jjjjjj................................................
....e.kkkk.lllllll.kkkkkk.g.........................................................................
m..ee.h.nn....oooooo.jj.jjjjjjj.jjjjjj..............................................................
...ee.h.nnnnn.ggooo.................................................................................
p..ee.h.nnn...qqqq..................................................................................
...ee.g.............................................................................................
...ee...............................................................................................
...ee.jj.jjjjj.jjjj.jjj.jjjjj.jjj.jjjjjjj.jjj.jjj.jjjjj.............................................
...ee.rrrr.gs.qqqqqqqg.tttttgg.ooo.g................................................................
p..ee.h.kkk.uuuuu.ooo...............................................................................
...ee.h.vvv.uw.uuuuu.xx.kkkkk.uwyyyyy.g.............................................................
...ee.h.h.uuuuu.xx.uuuuu............................................................................
...ee.h.g...........................................................................................
p..ee.h.zz.uwyyy.xx.AAA.g...........................................................................
p..ee.h.h.BBBBBB.uuuuu..............................................................................
p..ee.h.g...........................................................................................
...ee.h.BBBBBB.uwyyywCCCCCguuuuug...................................................................
...ee.g.............................................................................................
...ee...............................................................................................
...ee.jj.jjj.jjjjjjj.jjj.jjjjj.jj.jjjjjjjj..........................................................
DDDDDDDDEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEFFFFFGGGGHIcIIIIH
```

Legend: `a` [BufferLineIndicatorSelected] · `b` [BufferLineBufferSelected] · `c` [DevIconGo] · `d` [BufferLineFill] · `e` [LineNr] · `f` [@keyword.import] · `g` [@punctuation.bracket] · `h` [IblIndent] · `i` [@string] · `j` [@comment] · `k` [@keyword] · `l` [@type.definition] · `m` [GitSignsChange] · `n` [@variable.member] · `o` [@type.builtin] · `p` [GitCommittedSign] · `q` [@type] · `r` [@keyword.function] · `s` [@variable.parameter] · `t` [@function.method] · `u` [@variable] · `v` [@keyword.repeat] · `w` [@punctuation.delimiter] · `x` [@operator] · `y` [@property] · `z` [@keyword.conditional] · `A` [@character] · `B` [@keyword.return] · `C` [@function.method.call] · `D` [lualine_a_normal] · `E` [BufferLineBufferVisible] · `F` [lualine_x_diagnostics_error_normal] · `G` [lualine_x_diagnostics_warn_normal] · `H` [CursorLine] · `I` [StatuslineLangText] · `.` [Normal]

## Risks / Trade-offs

- **Fully new files are all purple.** A file added on the branch shows a bar on every line, which is right
  ("committed vs base") and matches IntelliJ's review mode. A 20 000-line generated file is skipped by
  `MAX_LINES`.
- **Line-level only.** A committed change and a later uncommitted change on the same line show only the
  gitsigns sign. That is the agreed precedence: local wins.
- **Stale after fetch.** The layer follows the merge-base that `git-branch-base` computes from local refs. It
  moves after a `git fetch`, through the git-dir watch.
- **Screenshots of checkout files.** No screen case opens a file of this checkout
  (`grep -rn "H.root" tests/screen` lists fixture copies only, 2026-10-19). Fixture repos are on `main` with no
  `origin`, so they have no base and no purple. A future screen case on a checkout file would depend on the
  loop branch. The task gate re-runs that grep.
