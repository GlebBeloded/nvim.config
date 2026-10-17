## Context

See proposal.md. What exists today and what we take from IntelliJ:

- **Today** `<A-g>` (`git.open_differ`) opens differ.nvim in a new tab: a 35-column file panel and a wrapped side-by-side split with `---` filler and 3 lines of context (Current below, a real capture). codediff and diffview are the other two viewers. None has a centre gutter, aligned padding or folded unchanged runs.
- **IntelliJ** (sparse clone `platform/diff-impl`):
  - `SimpleDiffViewer` in aligned mode ("align changes", `TextDiffSettingsHolder.ENABLE_ALIGNING_CHANGES_MODE`).
  - Defaults: `CONTEXT_RANGE = 4`, `HIGHLIGHT_POLICY = BY_WORD`, `IGNORE_POLICY = DEFAULT`, `ENABLE_SYNC_SCROLL = true`.
  - Folds come from `FoldingModelSupport.FoldingBuilderBase.addGroup`: `[start + context, end - context)`, only when at least 2 lines.
  - Sync scroll is `BaseSyncScrollable.transferLine`.
  - "Revert" is the left-side apply for local changes (`SimpleDiffChangeUi.getApplyActionText`).
- **Engine** (`diff-engine-lines`, `-words`, `-moves`):
  - `require("gleb.diff.engine").compare_lines(lines1, lines2, { policy, highlight, moves, limits })` returns `{ fragments, moves, too_big, timed_out }`. Ranges are 0-based, half-open.
  - `inner_columns(fragment, side, lines)` maps inner ranges to `{ row, col_start, col_end }` byte columns.
  - On `too_big`/`timed_out`, fragments are `vim.text.diff` histogram ranges.
- **Neovim 0.12 built-ins** checked in a child, in a planning probe:
  - `statuscolumn` is evaluated for virtual-line rows (`v:virtnum < 0`) and fold rows.
  - `virt_lines_leftcol` virtual lines bypass it.
  - `winrestview({ topfill })` shows virtual lines above line 1.
  - `nvim__ns_set(ns, { wins = { win } })` limits a namespace's extmarks to one window, so the same buffer in another window shows none of them.

## Goals / Non-Goals

**Goals:**
- The approved `diff2_aligned` look, cell for cell except the window separator column, on real Neovim windows.
- The real file buffer on the right: edit, undo, save and LSP work while the diff follows.
- An API the changes panel (`git-changes-tree`) embeds without a second tab.

**Non-Goals:**
- Arrow and checkbox behaviour, moves, and policy or mode toggles (`diff-view-actions`).
- Non-git comparisons, revisions other than `HEAD`, merges, binary files, and soft wrap.

## Decisions

1. **Modules** (rule 1):
   - `lua/gleb/diff/init.lua` requires `view.highlights` (the `ColorScheme` autocmd).
   - `lua/gleb/diff/actions.lua` holds the `diff.*` actions.
   - `lua/gleb/diff/view/`:
     - `init.lua`: the API, `M.state` and `M.reset()`, and `M.config` with `context = 4`, `debounce_ms = 150` and `timeout_ms = 1000`;
     - `layout.lua` (pure, rule 1.3): aligned rows, folds, line transfer, gutter cells and the change at a line;
     - `render.lua`: extmarks, `statuscolumn`, `foldtext`, winbar;
     - `windows.lua`: tab or split, window options, autocmds `gleb_diff_view`;
     - `source.lua`: git calls through `vim.system` argument lists;
     - `highlights.lua`.
   - The adapter is `lua/gleb/actions/adapters/gleb_diff.lua`. It follows `git_commit_popup.lua`, and its mappings are lhs → `Context.invoke(action)`.
2. **Source.** All git calls run with `vim.system` and an argument list:
   - `git rev-parse --show-toplevel` from the file's directory; a non-zero exit means `Not in a git repository`;
   - `git ls-files --full-name -- <file>` gives the repo-relative path;
   - `git show HEAD:<relpath>` for the left lines; a non-zero exit gives an empty left side;
   - `git rev-parse --short=7 HEAD` for the header.

   The right lines are `nvim_buf_get_lines` of the buffer. A trailing `"\n"` from `git show` is dropped, so both sides use the buffer line model. Comparison: `compare_lines(left, right, { policy = "default", highlight = "by_word" })`, with `limits.timeout_ms = M.config.timeout_ms`. Moves are off here.
3. **Windows.**
   - `open(spec)` runs `:tabnew`. `show(win, spec)` uses `win` itself as the right window and `:leftabove vsplit` for the left one, so the area is reused and the current window is restored.
   - The left width is `math.floor(0.4 × area width)`. The rest, minus the separator, is the right window.
   - Window-local options in both windows:
     - `number`, `relativenumber`, `cursorline`, `wrap` and `list` off;
     - `signcolumn=no` and `foldcolumn=0`;
     - `foldmethod=manual`, `foldenable` on, `foldtext` set by the view;
     - `fillchars` `fold:~,vert: ,eob: `;
     - `winhighlight` `WinBar:DiffViewHeader,WinBarNC:DiffViewHeader,Folded:DiffViewFold`.
   - The left `statuscolumn` is one cell: blank, the kind tint on a changed row, `~` on a fold row. The right `statuscolumn` is the 16-cell gutter (Decision 5). Both are `%!v:lua.require'gleb.diff.view.render'.statuscolumn()`, which reads `vim.g.statusline_winid`.
   - The left buffer: `buftype=nofile`, `bufhidden=wipe`, `modifiable=false`, filetype `gleb-diff`, and name `gleb-diff://HEAD/<relpath>`. Treesitter starts on it with `vim.treesitter.language.get_lang(<file filetype>)`, when a parser exists.
   - With `right` as lines, a second such buffer holds them, read-only.
4. **Aligned rows** (`layout.lua`).
   - The fragments and both line counts give an ordered row list. Each row is a pair of left line or pad and right line or pad, or a fold row of `n` hidden lines.
   - For a change `[s1,e1) × [s2,e2)`, the shorter side gets `|(e1-s1) - (e2-s2)|` pad rows after its lines.
   - Pads are `virt_lines` with `virt_lines_leftcol`, attached above the next line of that side, or below the last line at the end of the file. A pad in the right window carries the gutter cells as its first 16 cells.
   - Folds: each unchanged run keeps `context` lines next to each neighbouring change (none at file start or end). It folds the rest when at least 2 lines remain, as `FoldingBuilderBase.addGroup` does. The fold is `:fold` on the same line ranges in both windows.
   - The left `foldtext` is `{ { "~", "DiffViewFold" }, { " <n> unchanged lines ", "DiffViewFoldText" } }`; the right one is `{}`.
5. **Gutter cells** (right `statuscolumn`, 16 cells), in this order:

   | Cells | Content | Group |
   |---|---|---|
   | 1 | `»` on a change's first row, else blank | `DiffViewArrow<Kind>`, `Normal` |
   | 2–5 | left number `%3d ` or `╱╱╱╱` | `DiffViewLineNr` / `DiffViewGutter<Kind>` / `DiffViewPadding` |
   | 6–10 | strip | `DiffView<Kind>` on change rows, else blank |
   | 11–14 | right number `%3d ` or `╱╱╱╱` | as cells 2–5 |
   | 15 | `☐` (`U+F0131`) on a change's first row | `DiffViewGutter<Kind>`, or `DiffViewCheckbox` on a pad row |
   | 16 | blank | `DiffViewGutter<Kind>` on change rows |

   A fold row is 16 `~` in `DiffViewFold`. No checkbox is drawn when the left side is empty (a file absent from `HEAD`). The kind is `Add` (left empty), `Delete` (right empty) or `Change`.
6. **Highlights.**
   - Changed lines use `line_hl_group = DiffView<Kind>` extmarks. Word ranges use `hl_group = DiffViewWord` with priority above the line group, from `inner_columns`; zero-width entries are skipped.
   - All view extmarks live in namespace `gleb_diff_view`, scoped with `nvim__ns_set` to the view's windows.
   - Colours: `util.blend` from `lua/gleb/colors/gruvbox-material/util` over palette `bg0` (rule 8.7), as in the Colours requirement, recomputed on `ColorScheme`.
7. **Sync.** The view keeps the row list.
   - `WinScrolled` on either window finds the row at its top (`topline` and `topfill`, folds as one row). It sets the other window's `topline` and `topfill` to the same row, and the same `leftcol`. A guard flag stops the echo.
   - `CursorMoved` maps the line with `transferLine` over the row list and sets the other cursor without scrolling it beyond the sync.
8. **Navigation.** "The change at a line" and `]c`/`[c` targets use IntelliJ's `DiffUtil.isSelectedByLine`: an empty range at line `L` belongs to the line just below the gap. `]c` and `[c` act in the current window and never wrap.
9. **Editing.**
   - `nvim_buf_attach` `on_lines` (and `TextChanged` for reloads) on the right buffer restarts one `vim.uv` timer of `debounce_ms`. When it fires, the view re-compares and redraws under `vim.schedule`, after checking that the view and windows are still valid (rule 6.3).
   - Re-folding keeps a fold open when its new range intersects a range the user opened.
   - The fallback label is computed on every compare.
10. **Close.**
    - `diff.close`, or `WinClosed` of either window, runs one cleanup path:
      - it clears the namespace and the scoped windows;
      - it deletes the view's buffer-local mappings and re-sets the ones saved with `maparg(lhs, "n", false, true)` before mapping;
      - it detaches the buffer, stops the timer and deletes the autocmds;
      - it closes the other window, then the tab page for `open`, or restores the right window's options for `show`.
    - Focus returns to the window current before `open`.
11. **Keys.**
    - Actions with `plugin = "gleb-diff"`: `diff.next_change`, `diff.prev_change`, `diff.next_file`, `diff.expand_fold`, `diff.toggle_folds` and `diff.close`.
    - The view maps them buffer-local with `nowait` in both buffers, at open time.
    - `diff.open_file` is a normal action, `when` = the current buffer is a file (`buftype == ""` and a name), and has no `settings/keymap.json` entry.
    - Category: `Git | Diff`. Titles: "Open File Diff", "Next Change", "Previous Change", "Next File", "Expand Fold", "Toggle Folds", "Close Diff".
12. **Fixture `diffgo`** (`tests/fixtures/build.sh`, same hermetic git env as the others, so HEAD is `6ee5f08`).
    - `internal/user/controller.go` has 151 lines, with `Drop` on lines 50–67. The working tree changes line 53, inserts line 58 and deletes old line 65.
    - `internal/user/ids.go` is used by `diff-view-actions`.
    - The manifest holds `head` and both paths. The function and its helpers, verbatim:

```sh
# $1 first, $2 last: one 4-line block per step (blank, func, body, close)
ctl_steps() {
	i=$1
	while [ "$i" -le "$2" ]; do
		printf '\nfunc (c *Ctl) Step%d() error {\n\treturn c.step(%d)\n}\n' "$i" "$i"
		i=$((i + 1))
	done
}

# $1 old | new: internal/user/controller.go, 151 lines; Drop() is lines 50-67
ctl_controller() {
	printf '// Package user manages user accounts.\npackage user\n\nimport "log"\n\n'
	printf '// Ctl removes users and counts what it did.\n// It is not safe for concurrent use.\ntype Ctl struct {\n\tstats Stats\n}\n\n'
	printf '// Stats are the counters of a Ctl.\ntype Stats struct{ Removed, Skipped, LastRun Counter }\n\n'
	printf '// Counter is one metric.\ntype Counter interface{ Inc(); Touch() }\n'
	ctl_steps 1 8
	printf '\nfunc (c *Ctl) Drop(id string) error {\n\tuser, ok, err := c.lookup(id)\n\tif err != nil {\n'
	if [ "$1" = old ]; then printf '\t\treturn err\n'; else printf '\t\treturn wrap(err)\n'; fi
	printf '\t}\n\tif !ok {\n\t\tlog.Info("no user, skipping")\n\n'
	if [ "$1" = new ]; then printf '\t\tc.stats.Skipped.Inc()\n'; fi
	printf '\t\treturn err\n\t}\n\n\tif err = c.del(user); err != nil {\n\t\treturn err\n\t}\n\tc.stats.Removed.Inc()\n'
	if [ "$1" = old ]; then printf '\tc.stats.LastRun.Touch()\n'; fi
	printf '\treturn nil\n}\n'
	ctl_steps 9 29
}

# $1 old | new: internal/user/ids.go; new moves Validate (7 lines) below Key
ids_validate() {
	printf '// Validate rejects empty ids.\nfunc Validate(id string) error {\n\tif id == "" {\n\t\treturn errEmpty\n\t}\n\treturn nil\n}\n'
}
ids_rest() {
	printf '// Normalize trims and lowercases an id.\nfunc Normalize(id string) string {\n\treturn strings.ToLower(strings.TrimSpace(id))\n}\n'
	printf '// Key is the storage key of an id.\nfunc Key(id string) string {\n\treturn "user/" + Normalize(id)\n}\n'
}
ids() {
	printf 'package user\n\n'
	if [ "$1" = old ]; then ids_validate; ids_rest; else ids_rest; ids_validate; fi
}

diffgo() {
	git init -q
	mkdir -p internal/user
	ctl_controller old >internal/user/controller.go
	ids old >internal/user/ids.go
	commit "add user controller"
	ctl_controller new >internal/user/controller.go
	ids new >internal/user/ids.go
	printf '{"head":"%s","controller":"internal/user/controller.go","ids":"internal/user/ids.go"}\n' \
		"$(git rev-parse --short=7 HEAD)" >../manifest.json
}
```

## Risks / Trade-offs

- **`nvim__ns_set` is experimental.** It scopes the namespace to the view's windows. If its signature changes, the fallback is the stable `scoped` decorations of a later Neovim, or a copy of the buffer on the right. The unit tests pin the behaviour ("the file's other window shows no padding"), not the API.
- **The right window's text is the shared buffer.** A user edit in another window re-diffs the view too. That is intended: there is one document, as in IntelliJ.
- **One separator column.** Real windows force a blank separator at column 40, so the `╱` and `~` rows show a one-cell gap there. The approved mockup has no separator; the user should know about this gap (proposal, Agent decisions).
- **Large files.** The engine is bounded (1 s deadline, fallback); `approximate diff` says so. Redraw cost is extmarks per changed line, done once per compare.
- **Virtual lines at the top of a window** need `topfill`. Sync sets it explicitly, and the unit test covers a change at line 1.

## Renders

Stand-ins: `◆` devicon, `⎇` branch, `☐` include checkbox (`U+F0131`), `»` apply arrow, `╱` padding, `~` fold row. The real-glyph, real-colour renders are in `renders/*.ansi`; view them with `command cat`.

- **Current** is a real capture (`tests/render/tmux.lua` driven by a planning script on the `diffgo` fixture, then `<A-g>`). Its mask is resolved from the captured colours: only differ's diff tints and the separator are named.
- **Proposed** is generated from the approved `diff_gen.py` look on real windows. Every cell is annotated with its group. Code syntax colours are left unmasked (`.`), and so are the bufferline and statusline rows, which the screen scenario does not assert.
- The new `DiffView*` groups show as plain text in `make colorize` until this change creates them.

**Current — Differ on `<A-g>`**: `100x30`, Normal, `internal/user/controller.go` (diffgo fixture) after `<A-g>` (`git.open_differ`): a new tab with differ's 35-column panel, a wrapped side-by-side diff with 3 lines of context and a `---` filler; real capture.

```text
    ◆ controller.go                                                                       ▏ 1 ▕▏ 2 ▕
 ▕████████████▏ file 1/1           ┃ controller.go      ◆ hunk 1/3 ┃ controller.go       ◆ hunk 1/3 
/private/var/folders/9c/yg1yg4td727┃  43   return c.step(7)        ┃  43   return c.step(7)         
Help: g?              --stat +2 -2 ┃  44 }                         ┃  44 }                          
                                   ┃  45                           ┃  45                            
Unstaged (1) · internal/user/      ┃  46 func (c *Ctl) Step8() erro┃  46 func (c *Ctl) Step8() error
M ◆ controller.go            +2 -2 ┃     r {                       ┃      {                         
                                   ┃  47   return c.step(8)        ┃  47   return c.step(8)         
Showing changes for:               ┃  48 }                         ┃  48 }                          
ac4336a7ddefa45e996e5ab24dbd61e528d┃  49                           ┃  49                            
                                   ┃  50 func (c *Ctl) Drop(id stri┃  50 func (c *Ctl) Drop(id strin
                                   ┃     ng) error {               ┃     g) error {                 
                                   ┃  51   user, ok, err := c.looku┃  51   user, ok, err := c.lookup
                                   ┃     p(id)                     ┃     (id)                       
                                   ┃  52   if err != nil {         ┃  52   if err != nil {          
                                   ┃  53     return err            ┃  53     return wrap(err)       
                                   ┃  54   }                       ┃  54   }                        
                                   ┃  55   if !ok {                ┃  55   if !ok {                 
                                   ┃  56     log.Info("no user, ski┃  56     log.Info("no user, skip
                                   ┃     pping")                   ┃     ping")                     
                                   ┃  57                           ┃  57                            
                                   ┃     --------------------------┃  58     c.stats.Skipped.Inc()  
                                   ┃  58     return err            ┃  59     return err             
                                   ┃  59   }                       ┃  60   }                        
                                   ┃  60                           ┃  61                            
                                   ┃  61   if err = c.del(user); er┃  62   if err = c.del(user); err
                                   ┃     r != nil {                ┃      != nil {                  
                                   ┃  62     return err            ┃  63     return err             
                                   ┃  63   }                       ┃  64   }                        
 NORMAL                                                                     ◆ 0 ◆ 0 ◆ ◆ differdiff ◆
```

```text
....................................................................................................
...................................a...............................a................................
...................................a...............................a................................
...................................a...............................a................................
...................................a...............................a................................
...................................a...............................a................................
...................................a...............................a................................
...................................a...............................a................................
...................................a...............................a................................
...................................a...............................a................................
...................................a...............................a................................
...................................a...............................a................................
...................................a...............................a................................
...................................a...............................a................................
...................................a...............................a................................
...................................a.....bbbbbbbbbbbbbbbbbbbbbbbbbba.....cccccccccccdddddcccdccccccc
...................................a...............................a................................
...................................a...............................a................................
...................................a...............................a................................
...................................a...............................a................................
...................................a...............................a................................
...................................a...............................a.....ccccccccccccccccccccccccccc
...................................a...............................a................................
...................................a...............................a................................
...................................a...............................a................................
...................................a...............................a................................
...................................a...............................a................................
...................................a...............................a................................
...................................a...............................a................................
....................................................................................................
```

Legend: `a` [WinSeparator] · `b` [differCursorLineDelete] · `c` [differLineAdd] · `d` [differWordAdd] · `.` [Normal]

**Proposed D — aligned diff of the current file**: `100x30`, Normal, `internal/user/controller.go` (diffgo fixture, HEAD `6ee5f08`) after `diff.open_file`; new tab, cursor on right line 53 (first change), nothing staged.

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
