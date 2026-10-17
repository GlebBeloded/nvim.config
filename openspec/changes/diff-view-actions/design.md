## Context

See proposal.md. `diff-view` gives the aligned view, with:
- the right window as the real buffer;
- a row list (`view/layout.lua`) and a 16-cell gutter whose arrow and checkbox cells are drawn but inert;
- the `gleb-diff` action adapter.

IntelliJ references (sparse clone `platform/diff-impl`):
- `SimpleDiffChangeUi.createApplyRenderer` replaces the change from the source side (`replaceChange`). "Revert" is its left-side text for local changes.
- The include checkbox is the partial-commit exclusion state (`SimpleDiffChange.isExcluded`). We map it onto the git index, as the user's changes panel does.
- `TextDiffSettingsHolder` defaults to `IGNORE_POLICY = DEFAULT` and `HIGHLIGHT_POLICY = BY_WORD`. Its labels are those of `IgnorePolicy` and `HighlightPolicy`.

The engine (`diff-engine-moves`) returns `result.moves` (`{ start1, end1, start2, end2, fragments }`, 0-based half-open) with `opts.moves = true`.

Today, staging one hunk is possible only in differ's or diffview's own panels. The neo-tree `git_status` toggle (`file_tree/actions.lua`) stages whole files with `git add`/`git reset` and notifies `Stage failed: <stderr>` / `Unstage failed: <stderr>`.

## Goals / Non-Goals

**Goals:**
- IntelliJ's per-change Revert and include checkbox, with the checkbox meaning "staged".
- Moved blocks drawn on both ends, with a jump between them.
- The whitespace and highlight settings, persisted.

**Non-Goals:**
- Staging new files, Visual-mode ranges, Append, and differences inside moves.
- Commit and push (`git-changes-tree`).

## Decisions

1. **The change at the cursor** is `layout.change_at(side, line)`, as IntelliJ's `DiffUtil.isSelectedByLine`:
   - a non-empty range `[s,e)` contains the 0-based line `l` when `s <= l < e`;
   - an empty range at `s` is selected by `l == s`, the line just below the gap.
2. **Revert** (`diff.apply`): `nvim_buf_set_lines(right, s2, e2, false, left_lines[s1+1 .. e1])` in one call, so it is one undo step. Then the view re-compares at once, cancelling the pending debounce. The file is not written; autosave writes it as usual.
3. **Index states** (`patch.lua`, pure):
   - Inputs: the `HEAD` lines `H` (left), the index lines `I` (`git show :<relpath>`) and the right lines `R`. Let `S = compare_lines(H, I, { highlight = "by_line" })`.
   - For a change `C = [s1,e1) × [s2,e2)`, let `O` be the `S` fragments that overlap `[s1,e1)` on side 1. Ranges overlap when `a < d and c < b`, or when an empty one lies within the other, ends included.
   - Its state:
     - `☐` when `O` is empty;
     - `☑` when `O` is one fragment with `start1 = s1`, `end1 = e1` and `I[start2+1 .. end2] == R[s2+1 .. e2]`;
     - `◪` otherwise.
   - New index text:
     - Let `U = [u1,u2)` be the union of `[s1,e1)` and `O`'s side-1 ranges. Its index range `[i1,i2)` is `U` shifted by the line deltas of the `S` fragments before it, plus `O`'s own extents.
     - Stage: `I[1..i1] ++ H[u1+1..s1] ++ R[s2+1..e2] ++ H[e1+1..u2] ++ I[i2+1..]`.
     - Unstage: `I[1..i1] ++ H[u1+1..u2] ++ I[i2+1..]`.
     - Staged edits overlapping `U` but outside `C` therefore go back to `HEAD`. That is rare, and the result is shown at once by the checkbox.
   - Patch:
     - `vim.text.diff(old, new, { result_type = "unified", ctxlen = 3 })`, where `old` and `new` are the lines joined with `"\n"` plus a final `"\n"`. When the index blob or the buffer (`'eol'` off and `'fixeol'` off) has no final newline, there is none, and xdiff writes `\ No newline at end of file`.
     - It is prefixed with `diff --git a/<p> b/<p>`, `--- a/<p>` and `+++ b/<p>`, where `<p>` is the repo-relative path.
     - An empty patch does nothing.
4. **Git calls** (`stage.lua`):
   - `vim.system({ "git", "show", ":" .. relpath }, { cwd = root })` reads the index;
   - `vim.system({ "git", "apply", "--cached", "--whitespace=nowarn", "-" }, { cwd = root, stdin = patch })` applies the patch.

   On a non-zero exit, it notifies `Stage failed: ` or `Unstage failed: ` plus the trimmed stderr at ERROR (rule 6.4). Success is silent (rule 8.4). The calls are synchronous, as the existing toggle is, then the checkboxes refresh. A file whose index read fails gets no state, and its toggle reports the read's stderr.
5. **Checkbox drawing.**
   - `layout.lua` takes a state per change: `☐` `U+F0131`, `☑` `U+F0132`, `◪` `U+F0856`. The group is unchanged (`DiffViewGutter<Kind>`, or `DiffViewCheckbox` on a pad row).
   - States are recomputed after every compare and every toggle. Changing the buffer re-reads the index only on toggles and on `FocusGained`. A compare reuses the last `I`.
6. **Moves.**
   - The view compares with `moves = true`.
   - `layout.lua` marks the rows of each move's left lines `[start1,end1)` and right lines `[start2,end2)` as kind `Moved`: `DiffViewMoved` line highlight, `DiffViewGutterMoved` numbers and strip.
   - On the first row of each end, the strip's 5 cells hold `→<start2+1>` or `←<start1+1>`, left-aligned and cut at 5 cells, in `DiffViewMovedMarker`.
   - The `»` keeps its add or delete colour, because each end is still a revertable change.
   - `diff.jump_move` finds the move containing the cursor line on the current side, focuses the other window and sets its cursor to the other end's first line. Sync scroll then follows.
7. **Settings** (`settings.lua`, like `references/state.lua`):
   - `stdpath("state")/diff.json` holds `{ "policy": …, "highlight": … }`. It is validated against the engine's names, and anything invalid falls back to `default` / `by_word`.
   - `view.config` reads it once at setup. An action sets it, saves it and re-compares every open view.
   - With `none`, the engine returns no fragments. The row list then pairs lines by index, and nothing is folded, padded or marked.
8. **Actions** (`diff/actions.lua`), category `Git | Diff`:

   | id | title | key | kind |
   |---|---|---|---|
   | `diff.apply` | Revert Change | `do`, `dp` | `plugin = "gleb-diff"` |
   | `diff.toggle_include` | Toggle Change Staging | `<Space>` | `plugin = "gleb-diff"` |
   | `diff.jump_move` | Jump to Other End of Move | `gm` | `plugin = "gleb-diff"` |
   | `diff.ignore_none` | Do Not Ignore | – | radio toggle |
   | `diff.ignore_trim` | Trim Whitespaces | – | radio toggle |
   | `diff.ignore_whitespaces` | Ignore Whitespaces | – | radio toggle |
   | `diff.ignore_whitespaces_chunks` | Ignore Whitespaces and Empty Lines | – | radio toggle |
   | `diff.highlight_words` | Highlight Words | – | radio toggle |
   | `diff.highlight_split` | Highlight Split Changes | – | radio toggle |
   | `diff.highlight_chars` | Highlight Symbols | – | radio toggle |
   | `diff.highlight_lines` | Highlight Lines | – | radio toggle |
   | `diff.highlight_none` | Do Not Highlight | – | radio toggle |

   A radio toggle is `toggle.get = setting == value`, with `when` = a view is in the current tab page.
   - Within `gleb-diff`, the lhs set is `]c`, `[c`, `]f`, `zo`, `zR`, `q`, `do`, `dp`, `<Space>` and `gm`, with no duplicate.
   - `do`/`dp` do not shadow an operator: `d` itself is unmapped, and `o`/`p` are not motions.
9. **Colours.** `DiffViewMoved` is `util.blend(aqua, bg0, 0.72)`. `DiffViewGutterMoved` is `grey1` on it, and `DiffViewMovedMarker` is aqua on it. All are recomputed on `ColorScheme` with the other `DiffView*` groups.

## Risks / Trade-offs

- **The working tree on disk may differ from the buffer.** The checkbox compares the index with the buffer, so after an unsaved edit `git diff` (disk) and the view can disagree until autosave writes. This is intended: you stage what you see.
- **`vim.text.diff` unified output and the missing final newline.** A unit test pins a patch for a file without a final newline, applied with `git apply --cached --check`.
- **Overlapping staged edits** outside the toggled change revert to `HEAD` in the index (Decision 3). This is visible through `◪`/`☐` right away.
- **`gm` and `<Space>` shadow** native `gm` and the leader inside the two diff buffers while the view is open. They are restored on close (`diff-view`, closing).

## Renders

Stand-ins: `☐ ☑ ◪` checkbox empty / staged / mixed (`U+F0131`, `U+F0132`, `U+F0856`), `»` revert arrow, `╱` padding, `~` fold row, `→ ←` move markers, `◆` devicon, `⎇` branch.
- The real-glyph, real-colour renders are in `renders/*.ansi`; view them with `command cat`.
- Current is `diff-view`'s Proposed D, the state this change starts from.
- Proposed E1 and E2 come from the same generator, every cell annotated. Code syntax colours, the bufferline and the statusline are unmasked.
- The new `DiffViewMoved*` groups, and the `DiffView*` groups until `diff-view` lands, show as plain text in `make colorize`.

**Current — after `diff-view`**: `100x30`, Normal, `internal/user/controller.go` (diffgo fixture, HEAD `6ee5f08`) after `diff.open_file`; arrows and checkboxes are drawn but do nothing, moves are not shown.

```text
▎   ◆ controller.go                                                                      ▏ 1 ▕▏ 2 ▕ 
 6ee5f08 · HEAD                                          Your version                               
~~ 48 unchanged lines ~~~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                           49       49                                              
 func (c *Ctl) Drop(id string) error {     50       50   func (c *Ctl) Drop(id string) error {      
     user, ok, err := c.lookup(id)         51       51       user, ok, err := c.lookup(id)          
     if err != nil {                       52       52       if err != nil {                        
         return err                      » 53       53 ☐         return wrap(err)                   
     }                                     54       54       }                                      
     if !ok {                              55       55       if !ok {                               
         log.Info("no user, skipping")     56       56           log.Info("no user, skipping")      
                                           57       57                                              
╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱ »╱╱╱╱      58 ☐         c.stats.Skipped.Inc()              
         return err                        58       59           return err                         
     }                                     59       60       }                                      
                                           60       61                                              
     if err = c.del(user); err != nil {    61       62       if err = c.del(user); err != nil {     
         return err                        62       63           return err                         
     }                                     63       64       }                                      
     c.stats.Removed.Inc()                 64       65       c.stats.Removed.Inc()                  
     c.stats.LastRun.Touch()             » 65      ╱╱╱╱☐╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱
     return nil                            66       66       return nil                             
 }                                         67       67   }                                          
                                           68       68                                              
 func (c *Ctl) Step9() error {             69       69   func (c *Ctl) Step9() error {              
~~ 82 unchanged lines ~~~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                                                                                    
                                                                                                    
                                                                                                    
 NORMAL   ⎇ main                                                                                ◆ go
```

```text
....................................................................................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
ccddddddddddddddddddddccccccccccccccccccbccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
ffffffffffffffffffffffffffffffffffffffffbghhhhfffffhhhhhhfffffffffffffffiiiiifffifffffffffffffffffff
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
jjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjbkjjjjlllllmmmmmmlllllllllllllllllllllllllllllllllllllllllll
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnboppppnnnnnjjjjqjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
ccddddddddddddddddddddccccccccccccccccccbccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
........................................b...........................................................
........................................b...........................................................
........................................b...........................................................
....................................................................................................
```

Legend: `a` [DiffViewHeader] · `b` [WinSeparator] · `c` [DiffViewFold] · `d` [DiffViewFoldText] · `e` [DiffViewLineNr] · `f` [DiffViewChange] · `g` [DiffViewArrowChange] · `h` [DiffViewGutterChange] · `i` [DiffViewWord] · `j` [DiffViewPadding] · `k` [DiffViewArrowAdd] · `l` [DiffViewAdd] · `m` [DiffViewGutterAdd] · `n` [DiffViewDelete] · `o` [DiffViewArrowDelete] · `p` [DiffViewGutterDelete] · `q` [DiffViewCheckbox] · `.` [Normal]

**Proposed E1 — first change staged**: `100x30`, Normal, as Proposed D after `<Space>` on right line 53: the index holds `return wrap(err)`, the other two changes are not staged.

```text
▎   ◆ controller.go                                                                      ▏ 1 ▕▏ 2 ▕ 
 6ee5f08 · HEAD                                          Your version                               
~~ 48 unchanged lines ~~~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                           49       49                                              
 func (c *Ctl) Drop(id string) error {     50       50   func (c *Ctl) Drop(id string) error {      
     user, ok, err := c.lookup(id)         51       51       user, ok, err := c.lookup(id)          
     if err != nil {                       52       52       if err != nil {                        
         return err                      » 53       53 ☑         return wrap(err)                   
     }                                     54       54       }                                      
     if !ok {                              55       55       if !ok {                               
         log.Info("no user, skipping")     56       56           log.Info("no user, skipping")      
                                           57       57                                              
╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱ »╱╱╱╱      58 ☐         c.stats.Skipped.Inc()              
         return err                        58       59           return err                         
     }                                     59       60       }                                      
                                           60       61                                              
     if err = c.del(user); err != nil {    61       62       if err = c.del(user); err != nil {     
         return err                        62       63           return err                         
     }                                     63       64       }                                      
     c.stats.Removed.Inc()                 64       65       c.stats.Removed.Inc()                  
     c.stats.LastRun.Touch()             » 65      ╱╱╱╱☐╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱
     return nil                            66       66       return nil                             
 }                                         67       67   }                                          
                                           68       68                                              
 func (c *Ctl) Step9() error {             69       69   func (c *Ctl) Step9() error {              
~~ 82 unchanged lines ~~~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                                                                                    
                                                                                                    
                                                                                                    
 NORMAL   ⎇ main                                                                                ◆ go
```

```text
....................................................................................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
ccddddddddddddddddddddccccccccccccccccccbccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
ffffffffffffffffffffffffffffffffffffffffbghhhhfffffhhhhhhfffffffffffffffiiiiifffifffffffffffffffffff
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
jjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjbkjjjjlllllmmmmmmlllllllllllllllllllllllllllllllllllllllllll
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnboppppnnnnnjjjjqjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
........................................b.eeee.....eeee.............................................
ccddddddddddddddddddddccccccccccccccccccbccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
........................................b...........................................................
........................................b...........................................................
........................................b...........................................................
....................................................................................................
```

Legend: `a` [DiffViewHeader] · `b` [WinSeparator] · `c` [DiffViewFold] · `d` [DiffViewFoldText] · `e` [DiffViewLineNr] · `f` [DiffViewChange] · `g` [DiffViewArrowChange] · `h` [DiffViewGutterChange] · `i` [DiffViewWord] · `j` [DiffViewPadding] · `k` [DiffViewArrowAdd] · `l` [DiffViewAdd] · `m` [DiffViewGutterAdd] · `n` [DiffViewDelete] · `o` [DiffViewArrowDelete] · `p` [DiffViewGutterDelete] · `q` [DiffViewCheckbox] · `.` [Normal]

**Proposed E2 — moved block**: `100x30`, Normal, `internal/user/ids.go` (diffgo fixture) after `diff.open_file`: `Validate` (old 3-9) moved below `Key` (new 11-17); cursor on right line 11.

```text
▎   ◆ ids.go                                                                             ▏ 1 ▕▏ 2 ▕ 
 6ee5f08 · HEAD                                          Your version                               
 package user                               1        1   package user                               
                                            2        2                                              
 // Validate rejects empty ids.          »  3 →11  ╱╱╱╱☐╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱
 func Validate(id string) error {           4      ╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱
     if id == "" {                          5      ╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱
         return errEmpty                    6      ╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱
     }                                      7      ╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱
     return nil                             8      ╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱
 }                                          9      ╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱
 // Normalize trims and lowercases an id   10        3   // Normalize trims and lowercases an id.   
 func Normalize(id string) string {        11        4   func Normalize(id string) string {         
     return strings.ToLower(strings.Trim   12        5       return strings.ToLower(strings.TrimSpac
 }                                         13        6   }                                          
 // Key is the storage key of an id.       14        7   // Key is the storage key of an id.        
 func Key(id string) string {              15        8   func Key(id string) string {               
     return "user/" + Normalize(id)        16        9       return "user/" + Normalize(id)         
 }                                         17       10   }                                          
╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱ »╱╱╱╱←3    11 ☐ // Validate rejects empty ids.             
╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱  ╱╱╱╱      12   func Validate(id string) error {           
╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱  ╱╱╱╱      13       if id == "" {                          
╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱  ╱╱╱╱      14           return errEmpty                    
╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱  ╱╱╱╱      15       }                                      
╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱  ╱╱╱╱      16       return nil                             
╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱  ╱╱╱╱      17   }                                          
                                                                                                    
                                                                                                    
                                                                                                    
 NORMAL   ⎇ main                                                                                ◆ go
```

```text
....................................................................................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
........................................b.cccc.....cccc.............................................
........................................b.cccc.....cccc.............................................
ddddddddddddddddddddddddddddddddddddddddbeffffggggghhhhihhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh
ddddddddddddddddddddddddddddddddddddddddb.ffffdddddhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh
ddddddddddddddddddddddddddddddddddddddddb.ffffdddddhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh
ddddddddddddddddddddddddddddddddddddddddb.ffffdddddhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh
ddddddddddddddddddddddddddddddddddddddddb.ffffdddddhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh
ddddddddddddddddddddddddddddddddddddddddb.ffffdddddhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh
ddddddddddddddddddddddddddddddddddddddddb.ffffdddddhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh
........................................b.cccc.....cccc.............................................
........................................b.cccc.....cccc.............................................
........................................b.cccc.....cccc.............................................
........................................b.cccc.....cccc.............................................
........................................b.cccc.....cccc.............................................
........................................b.cccc.....cccc.............................................
........................................b.cccc.....cccc.............................................
........................................b.cccc.....cccc.............................................
hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhbjhhhhgggggffffffddddddddddddddddddddddddddddddddddddddddddd
hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhb.hhhhdddddffffffddddddddddddddddddddddddddddddddddddddddddd
hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhb.hhhhdddddffffffddddddddddddddddddddddddddddddddddddddddddd
hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhb.hhhhdddddffffffddddddddddddddddddddddddddddddddddddddddddd
hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhb.hhhhdddddffffffddddddddddddddddddddddddddddddddddddddddddd
hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhb.hhhhdddddffffffddddddddddddddddddddddddddddddddddddddddddd
hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhb.hhhhdddddffffffddddddddddddddddddddddddddddddddddddddddddd
........................................b...........................................................
........................................b...........................................................
........................................b...........................................................
....................................................................................................
```

Legend: `a` [DiffViewHeader] · `b` [WinSeparator] · `c` [DiffViewLineNr] · `d` [DiffViewMoved] · `e` [DiffViewArrowDelete] · `f` [DiffViewGutterMoved] · `g` [DiffViewMovedMarker] · `h` [DiffViewPadding] · `i` [DiffViewCheckbox] · `j` [DiffViewArrowAdd] · `.` [Normal]
