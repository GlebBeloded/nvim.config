## Context

See proposal.md (Why). `file-tree-view` builds the tree: model, render, view, the git status query in `git.lua`, the libuv watcher and the `FileTree*` groups. `file-tree-nesting` adds `settings/file_tree.json` with its loader `settings.lua`, and nests a folder's files after listing it. This change decides which listed entries are ignored and how they show.

Research (2026-10-17):
- **IntelliJ** has two layers:
  - VCS-ignored files are shown in olive, and the Project view filter "Show Excluded Files" hides excluded ones.
  - "Ignored Files and Folders" (Settings › File Types) are never shown at all; `.git` is among them by default.

  The user picked hiding with one Show Ignored action and grey italic (`ign_dim`) over olive (`ign_olive`).
- **VS Code** has `files.exclude` (never shown) and `explorer.excludeGitIgnore`. Gitignored files that are shown are dimmed.
- **Git queries**, checked with git 2.50.1 on a probe repo holding `bin/`, `web/node_modules/`, `.env`, `*.log` and a tracked `build/keep.txt` under an ignored `build/`:
  - `git ls-files --others --ignored --exclude-standard --directory -z` prints `.env`, `bin/`, `build/out.bin`, `internal/debug.log`, `web/node_modules/`:
    - ignored folders appear once, with a trailing `/`;
    - a folder that holds a tracked file is not ignored as a whole (only `build/out.bin` is);
    - tracked files never appear.
  - Run from a subfolder, it lists only that subtree, with paths relative to it. So it runs at the top level.
  - `git status --ignored=matching` gives the same set, but it can't be combined with `-uno` ("Unsupported combination") and would change the status query of `file-tree-view`.
  - `git check-ignore --stdin` answers per path, so every listed path would have to be piped in.
- **Globs:** `vim.glob.to_lpeg` (built in since Neovim 0.10) handles `*`, `**`, `?`, `{a,b}` and `[…]`.

## Goals / Non-Goals

**Goals:**
- Ignored = gitignored + `.git` + user globs, hidden by default with no trace, one toggle to show them.
- Never walk big ignored folders (`node_modules`) unless the user expands one.
- The same behaviour in and outside git repositories, minus the git part.

**Non-Goals:**
- Hint rows, counts, or per-folder exclude actions.
- Ignoring tracked files, nested repositories' own ignore files.

## Decisions

1. **The ignored set** (`lua/gleb/file_tree/ignore.lua`, pure):
   - `M.matcher(globs)` compiles the `ignore` list with `vim.glob.to_lpeg`:
     - a pattern without `/` is matched against the entry name;
     - one with `/` is matched against the path relative to the tree root;
     - a trailing `/` matches folders only.
   - `M.is_ignored(set, matcher, rel_path, is_dir)` is true when any of these holds:
     - `rel_path` or one of its parent folders is in `set` (the git paths, mapped from the top level to the tree root);
     - the matcher matches it or one of its parent folders.
   - `.git` (a folder, or a file in worktrees) is already dropped in the listing by `file-tree-view`. It stays dropped with Show Ignored on.
   - `settings.lua` validates `ignore` as a list of strings. A bad entry is skipped with WARN `File tree ignore pattern <n> skipped: <reason>`, as for nesting rules.
2. **The git query** (`git.lua`):
   - Per refresh of a tree inside a repository, one `vim.system({ "git", "ls-files", "--others", "--ignored", "--exclude-standard", "--directory", "-z" }, { cwd = toplevel })` runs next to the status query, on the same triggers: watcher event, `BufWritePost`, `FocusGained` and `file_tree.refresh`.
   - The NUL-separated output becomes a set. A trailing `/` marks a folder.
   - Results carry the refresh generation, and a stale result is dropped (rule 6.3).
   - A non-zero exit keeps the previous set. It is silent, because it is background work (rule 8.4).
   - Outside a repository (no top level from `file-tree-view`'s root detection) the query is never spawned.
3. **Hiding.**
   - The model filters each folder listing before nesting. Ignored children therefore never join a nest, and a parent left without visible children loses its chevron.
   - No hint, count or summary row exists.
   - Follow and reveal skip a hidden ignored file: the tree keeps its cursor and expansion.
   - Ops (`file-tree-ops`) still work on paths the user types. A new file that is ignored just isn't listed.
4. **First paint.**
   - When a tree root is first listed, rendering waits for the first ignored result, up to `IGNORE_WAIT_MS = 300`. After that it renders anyway, and re-renders when the result arrives. So `node_modules` doesn't flash on open in a normal repo.
   - Later refreshes never wait.
5. **Show Ignored.**
   - `file_tree.show_ignored` in `lua/gleb/file_tree/actions.lua`: title "Show Ignored", category "Project" (the category of every `file_tree.*` action), `ft = "gleb-file-tree"`.
   - Its `toggle` reads and writes the state, and `run` flips it. Shortcut key and palette do the same thing (loop lesson: toggles get a real `run`).
   - `settings/keymap.json` gets `"file_tree.show_ignored": ["I"]`.
   - State: `lua/gleb/file_tree/state.lua` (pattern of `references/state.lua`) reads and writes `stdpath("state")/file_tree/view.json` (next to `file-tree-view`'s `expanded.json`) as `{ "show_ignored": boolean }`. A missing or invalid file means off. The value is saved on every toggle and read when a tree opens.
   - Toggling re-renders every open tree and keeps the cursor on the same path when it is still listed.
6. **Look and no descent.**
   - `FileTreeIgnored = { fg = palette.grey0, italic = true }`, defined with the other `FileTree*` groups and re-applied on `ColorScheme` (rule 8.7).
   - On an ignored row, the folder icon or devicon and the name use it, and the expander keeps `FileTreeExpander`. The approved mockup drew folder icons in grey1. One group for every ignored icon is the agent's simplification (proposal).
   - Ignored rows skip the git colour lookup, and the folder tint ignores them. Git never reports status inside ignored folders anyway.
   - No descent:
     - An ignored folder is listed with its name only. Its `fs_scandir` and watcher start only when the user expands it.
     - `file_tree.unfold_all` skips ignored folders.
     - Children of an ignored folder are ignored by Decision 1's parent check, with no git call.
7. **Fixture.** `treeproj` (`file-tree-view`, with the files of `file-tree-nesting` Decision 8) already has ignored entries. This change relies on exactly these and adds whatever is missing. None of them is tracked:
   - `bin/server` (a shell script);
   - `web/node_modules/left-pad/index.js`;
   - `.env` (`TAX_RATE=0.2`).

   Its committed `.gitignore` holds `bin/`, `node_modules/`, `.env` and `*.log`, one per line. Scenarios that need other files (`audit.log`, `debug.log`, `.swp` files) create them in their own copy.

## Risks / Trade-offs

- **Large repositories.** `ls-files --others` walks the work tree like `git status` does. It runs async and no more often than the status query, and `--directory` stops at ignored folders.
- **Untracked nested repositories** are reported by git as untracked folders, not ignored ones, so they stay listed.
- **The 300 ms wait** delays first paint in very slow repositories. After it, entries may still appear and then hide once.
- **Glob semantics** follow `vim.glob`, not every `.gitignore` detail (no negation `!`). Negation belongs in `.gitignore`.

## Renders

- Stand-ins: `▸ ▾` expander and nest chevron, `■ □` folder closed/open, `◆` devicon, `⎇` branch.
- The real-glyph, real-colour renders are `renders/ign_current.ansi` and `renders/ign_proposed.ansi`; view them with `command cat`.
- `FileTreeIgnored` is new here. The other `FileTree*` groups come from `file-tree-view`, so until it lands `make colorize` shows them as plain text.
- Current equals `file-tree-nesting`'s Proposed render. Proposed equals the approved `ign_dim.ansi` cell for cell, except the statusline filetype (`gleb-file-tree`) and the two ignored folder icons (grey0, not grey1).

**Current — ignored entries hidden**: `100x30`, Normal, tree focused, `treeproj` fixture on `feat/tax` (`file-tree-nesting` Decision 8, ignored entries per Decision 7), `cmd/server`, `internal/billing` and `web/src` expanded, cursor on `invoice.go`, right window `internal/billing/invoice.go` at line 17; nests as in `file-tree-nesting`. `bin/`, `web/node_modules/` and `.env` are ignored and not listed; no hint row.

```text
                                     ◆ invoice.go                                                   
 ▾ □ billing  ~/work/billing       ┃   1 package billing                                            
   ▸ ■ .github/workflows           ┃   2                                                            
   ▾ □ cmd/server                  ┃   3 import (                                                   
       ◆ main.go                   ┃   4     "fmt"                                                  
   ▾ □ internal                    ┃   5                                                            
     ▾ □ billing                   ┃   6     "example.com/billing/internal/money"                   
       ▸ ◆ discount.go             ┃   7 )                                                          
       ▾ ◆ invoice.go              ┃   8                                                            
           ◆ invoice_test.go       ┃   9 // Invoice is a list of line amounts in cents.             
       ▸ ◆ tax.go                  ┃  10 type Invoice struct {                                      
     ▸ ■ money                     ┃  11     ID    string                                           
   ▾ □ web                         ┃  12     Lines []int                                            
     ▾ □ src                       ┃  13     Tax   Rate                                             
         ◆ cart.tsx                ┃  14 }                                                          
       ▸ ◆ price.ts                ┃  15                                                            
     ▸ ◆ package.json              ┃  16 // Total sums the lines and applies the tax rate.          
     ◆ .gitignore                  ┃  17 func (i Invoice) Total() int {                             
   ▸ ◆ go.mod                      ┃  18     total := 0                                             
     ◆ Makefile                    ┃  19     for _, cents := range i.Lines {                        
     ◆ notes.md                    ┃  20         total += cents                                     
     ◆ README.md                   ┃  21     }                                                      
                                   ┃  22     return i.Tax.Apply(total)                              
                                   ┃  23 }                                                          
                                   ┃  24                                                            
                                   ┃  25 // Due renders the total as dollars.                       
                                   ┃  26 func (i Invoice) Due() string {                            
                                   ┃  27     return fmt.Sprintf("due %s", money.Format(i.Total()))  
                                   ┃  28 }                                                          
 NORMAL  ⎇ feat/tax                                                                 gleb-file-tree  
```

```text
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabcabbbbbbbbbbbbaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
dd.e.fffffff..gggggggggggggg.......hiiiiijjjjjjj....................................................
...d.e.kkkkkkkkkkkkkkkkk...........hiiiii...........................................................
...d.e.kkkkkkkkkk..................hiiiiijjjjjj.....................................................
.......c.lllllll...................hiiiii....mmmmm..................................................
...d.e.nnnnnnnn....................hiiiii...........................................................
.....d.e.nnnnnnn...................hiiiii....mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm...................
.......d.c.lllllllllll.............hiiiii...........................................................
ooooooodoconnnnnnnnnnoooooooooooooohiiiii...........................................................
...........c.nnnnnnnnnnnnnnn.......hiiiiipp.ppppppp.pp.p.pppp.pp.pppp.ppppppp.pp.pppppp.............
.......d.c.qqqqqq..................hiiiiijjjj.rrrrrrr.jjjjjj........................................
.....d.e.kkkkk.....................hiiiii....rr....rrrrrr...........................................
...d.e.nnn.........................hiiiii....rrrrr...rrr............................................
.....d.e.nnn.......................hiiiii....rrr...rrrr.............................................
.........s.llllllll................hiiiii...........................................................
.......d.t.nnnnnnnn................hiiiii...........................................................
.....d.u.llllllllllll..............hiiiiipp.ppppp.pppp.ppp.ppppp.ppp.ppppppp.ppp.ppp.ppppp..........
.....v.llllllllll..................hwwwwwjjjj....rrrrrrr..xxxxx...rrr...............................
...d.y.llllll......................hiiiii.............z.............................................
.....A.llllllll....................hiiiii....jjj.............jjjjj...rrrrr..........................
.....B.CCCCCCCC....................hiiiii...........................................................
.....D.lllllllll...................hiiiii...........................................................
...................................hiiiii....jjjjjj...rrr.xxxxx.....................................
...................................hiiiii...........................................................
...................................hiiiii...........................................................
...................................hiiiiipp.ppp.ppppppp.ppp.ppppp.pp.pppppppp.......................
...................................hiiiiijjjj....rrrrrrr..xxx...rrrrrr..............................
...................................hiiiii....jjjjjj.....xxxxxxx.mmmm.mmm........xxxxxx...xxxxx......
...................................hiiiii...........................................................
EEEEEEEEFGGGGGGGGGGGFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFGGGGGGGGGGGGGGGGF
```

Legend: `a` [BufferLineFill] · `b` [BufferLineBufferSelected] · `c` [DevIconGo] · `d` [FileTreeExpander] · `e` [FileTreeFolderIcon] · `f` [FileTreeRoot] · `g` [FileTreeRootPath] · `h` [WinSeparator] · `i` [LineNr] · `j` [@keyword] · `k` [FileTreeFolderName] · `l` [FileTreeFileName] · `m` [@string] · `n` [FileTreeGitModified] · `o` [FileTreeCursorLine] · `p` [@comment] · `q` [FileTreeGitAdded] · `r` [@type] · `s` [DevIconTsx] · `t` [DevIconTypeScript] · `u` [DevIconPackageJson] · `v` [DevIconGitIgnore] · `w` [CursorLineNr] · `x` [@function.call] · `y` [DevIconGoMod] · `z` [@number] · `A` [DevIconMakefile] · `B` [DevIconMd] · `C` [FileTreeGitUntracked] · `D` [DevIconReadme] · `E` [lualine_a_normal] · `F` [lualine_c_normal] · `G` [lualine_b_normal] · `.` [Normal]

**Proposed — after Show Ignored**: the same state after `I` (`file_tree.show_ignored` on). Ignored rows are grey italic with grey icons. Equals the approved `ign_dim` screen, except that ignored folder icons use `FileTreeIgnored` too.

```text
                                     ◆ invoice.go                                                   
 ▾ □ billing  ~/work/billing       ┃   1 package billing                                            
   ▸ ■ .github/workflows           ┃   2                                                            
   ▸ ■ bin                         ┃   3 import (                                                   
   ▾ □ cmd/server                  ┃   4     "fmt"                                                  
       ◆ main.go                   ┃   5                                                            
   ▾ □ internal                    ┃   6     "example.com/billing/internal/money"                   
     ▾ □ billing                   ┃   7 )                                                          
       ▸ ◆ discount.go             ┃   8                                                            
       ▾ ◆ invoice.go              ┃   9 // Invoice is a list of line amounts in cents.             
           ◆ invoice_test.go       ┃  10 type Invoice struct {                                      
       ▸ ◆ tax.go                  ┃  11     ID    string                                           
     ▸ ■ money                     ┃  12     Lines []int                                            
   ▾ □ web                         ┃  13     Tax   Rate                                             
     ▸ ■ node_modules              ┃  14 }                                                          
     ▾ □ src                       ┃  15                                                            
         ◆ cart.tsx                ┃  16 // Total sums the lines and applies the tax rate.          
       ▸ ◆ price.ts                ┃  17 func (i Invoice) Total() int {                             
     ▸ ◆ package.json              ┃  18     total := 0                                             
     ◆ .env                        ┃  19     for _, cents := range i.Lines {                        
     ◆ .gitignore                  ┃  20         total += cents                                     
   ▸ ◆ go.mod                      ┃  21     }                                                      
     ◆ Makefile                    ┃  22     return i.Tax.Apply(total)                              
     ◆ notes.md                    ┃  23 }                                                          
     ◆ README.md                   ┃  24                                                            
                                   ┃  25 // Due renders the total as dollars.                       
                                   ┃  26 func (i Invoice) Due() string {                            
                                   ┃  27     return fmt.Sprintf("due %s", money.Format(i.Total()))  
                                   ┃  28 }                                                          
 NORMAL  ⎇ feat/tax                                                                 gleb-file-tree  
```

```text
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabcabbbbbbbbbbbbaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
dd.e.fffffff..gggggggggggggg.......hiiiiijjjjjjj....................................................
...d.e.kkkkkkkkkkkkkkkkk...........hiiiii...........................................................
...d.l.lll.........................hiiiiijjjjjj.....................................................
...d.e.kkkkkkkkkk..................hiiiii....mmmmm..................................................
.......c.nnnnnnn...................hiiiii...........................................................
...d.e.oooooooo....................hiiiii....mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm...................
.....d.e.ooooooo...................hiiiii...........................................................
.......d.c.nnnnnnnnnnn.............hiiiii...........................................................
pppppppdpcpoooooooooopppppppppppppphiiiiiqq.qqqqqqq.qq.q.qqqq.qq.qqqq.qqqqqqq.qq.qqqqqq.............
...........c.ooooooooooooooo.......hiiiiijjjj.rrrrrrr.jjjjjj........................................
.......d.c.ssssss..................hiiiii....rr....rrrrrr...........................................
.....d.e.kkkkk.....................hiiiii....rrrrr...rrr............................................
...d.e.ooo.........................hiiiii....rrr...rrrr.............................................
.....d.l.llllllllllll..............hiiiii...........................................................
.....d.e.ooo.......................hiiiii...........................................................
.........t.nnnnnnnn................hiiiiiqq.qqqqq.qqqq.qqq.qqqqq.qqq.qqqqqqq.qqq.qqq.qqqqq..........
.......d.u.oooooooo................hvvvvvjjjj....rrrrrrr..wwwww...rrr...............................
.....d.x.nnnnnnnnnnnn..............hiiiii.............y.............................................
.....l.llll........................hiiiii....jjj.............jjjjj...rrrrr..........................
.....z.nnnnnnnnnn..................hiiiii...........................................................
...d.A.nnnnnn......................hiiiii...........................................................
.....B.nnnnnnnn....................hiiiii....jjjjjj...rrr.wwwww.....................................
.....C.DDDDDDDD....................hiiiii...........................................................
.....E.nnnnnnnnn...................hiiiii...........................................................
...................................hiiiiiqq.qqq.qqqqqqq.qqq.qqqqq.qq.qqqqqqqq.......................
...................................hiiiiijjjj....rrrrrrr..www...rrrrrr..............................
...................................hiiiii....jjjjjj.....wwwwwww.mmmm.mmm........wwwwww...wwwww......
...................................hiiiii...........................................................
FFFFFFFFGHHHHHHHHHHHGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGHHHHHHHHHHHHHHHHG
```

Legend: `a` [BufferLineFill] · `b` [BufferLineBufferSelected] · `c` [DevIconGo] · `d` [FileTreeExpander] · `e` [FileTreeFolderIcon] · `f` [FileTreeRoot] · `g` [FileTreeRootPath] · `h` [WinSeparator] · `i` [LineNr] · `j` [@keyword] · `k` [FileTreeFolderName] · `l` [FileTreeIgnored] · `m` [@string] · `n` [FileTreeFileName] · `o` [FileTreeGitModified] · `p` [FileTreeCursorLine] · `q` [@comment] · `r` [@type] · `s` [FileTreeGitAdded] · `t` [DevIconTsx] · `u` [DevIconTypeScript] · `v` [CursorLineNr] · `w` [@function.call] · `x` [DevIconPackageJson] · `y` [@number] · `z` [DevIconGitIgnore] · `A` [DevIconGoMod] · `B` [DevIconMakefile] · `C` [DevIconMd] · `D` [FileTreeGitUntracked] · `E` [DevIconReadme] · `F` [lualine_a_normal] · `G` [lualine_c_normal] · `H` [lualine_b_normal] · `.` [Normal]
