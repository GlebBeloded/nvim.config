## Context

See proposal.md (Why). `file-tree-view` builds the project tree:
- a pure model (`lua/gleb/file_tree/model.lua`), `render.lua` and `view.lua` in filetype `gleb-file-tree`;
- the `FileTree*` groups, compact folder chains and git name colours with folder tint;
- the scoped actions `file_tree.open`, `close_node`, `toggle_fold`, `fold_all` and `unfold_all`.

`file-tree-ops` adds add, delete, rename, copy, cut, paste and refresh. This change puts file nesting between the folder listing and the rows.

Research (2026-10-17):
- **VS Code** (`explorer.fileNesting.patterns`, `src/vs/workbench/contrib/files/common/explorerFileNestingTrie.ts`):
  - A parent key is a glob with at most one `*`, and the text it matches is `${capture}`. Children are globs with `${capture}`, `${basename}`, `${extname}` and `${dirname}`.
  - A child that is itself a parent is followed up to its root, so nesting shows one level.
  - A file with two parents is listed under both. A pure cycle leaves every member a root.
  - Nests start collapsed (`explorer.fileNesting.expand: false` is the common setting).
- **IntelliJ** (File Nesting dialog): a rule is a parent suffix with child suffixes (`.go` → `_test.go`). It works only within one folder and one level, and the parent shows a chevron. There is no regex and no capture.
- **neo-tree** (`nesting_rules`): pattern rules with `files` globs and an `ignore_case` flag. It is neo-tree-internal and goes away at `tree-diff-cutover`.
- **Matchers available in Lua:**
  - Lua patterns (`string.match`) have captures and are pure Lua. They have no alternation.
  - `vim.regex` has no capture API, so captures need `vim.fn.matchlist` per name.
  - `vim.glob.to_lpeg` builds globs without captures.

## Goals / Non-Goals

**Goals:**
- The user's full recommended rule set out of the box, editable in one versioned JSON file.
- Regex rules with captures (the first iteration the user asked for), plus Lua function rules for anything a pattern can't express.
- A deterministic, pure engine: one row per file, the same result for the same listing.
- Nests that behave like folders in the view (chevron, collapsed, fold all and unfold all, tint).

**Non-Goals:**
- Multi-level or cross-folder nesting, glob syntax, a settings UI, folder nesting.
- Changing what neo-tree shows (it stays until `tree-diff-cutover`).

## Decisions

1. **Settings file and loader.**
   - `settings/file_tree.json` lives in the repo, next to `settings/keymap.json`. It is one JSON object:
     - `nesting.enabled` (boolean, default `true`);
     - `nesting.rules` (array);
     - `ignore`, added by `file-tree-ignored`.
   - `lua/gleb/file_tree/settings.lua`:
     - `M.load(path?)` reads the file once and caches the validated result in `M.state`, and `M.reset()` clears it (rule 1.5).
     - The path defaults to `stdpath("config") .. "/settings/file_tree.json"`. `M.setup({ path = … })` overrides it, so tests use a temporary copy and never edit the checkout.
   - A missing file means no rules, silently.
   - JSON that does not decode, or whose `nesting` is not an object, gives one ERROR `File tree settings invalid: <error>` and no nesting. The tree still renders: degrade, don't crash.
   - A `BufWritePost` autocmd on the `fs.normalize`d resolved path (augroup `gleb_file_tree_settings`) clears the cache, bumps the settings generation and re-renders every open tree. Normalization makes `/var` and `/private/var` spellings match. A reload that warns again shows its warnings again.
2. **Rule syntax: Lua patterns with captures.**
   - `parent` and every `children` entry are Lua patterns. The loader anchors each one to the whole name (`^…$`), after stripping a leading `^` and a trailing unescaped `$` the user may have written.
   - In a child, `${capture}` is capture 1, and `${1}`…`${9}` are captures 1–9 of the parent match. Each is inserted through `vim.pesc`, so `a.b.ts` nests `a.b.test.ts` and never `aXb.test.ts`.
   - A rule is skipped with WARN `File tree nesting rule <n> skipped: <reason>` (once per rule per load) when:
     - its pattern fails to compile (`pcall(string.find, "", pattern)`);
     - a child names a capture the parent doesn't have;
     - `parent` or `children` is missing or has the wrong type.
   - Why Lua patterns over the alternatives:
     - They are pure Lua, so `nesting.lua` follows rule 1.3 and runs in a bare child.
     - Captures come back from `string.match` directly.
     - JSON needs no doubled backslashes (`%.go`, not `\\.go`).
     - Alternation, which they lack, is covered by listing several children.
     - vim.regex would need `matchlist` per name for captures. Globs (VS Code) can't express `test_${capture}.py` with more than one capture, and the user asked for regexp.
3. **Engine** `nesting.nest(dir, entries, rules)` → `table<string, string[]>`, pure. `entries` use the shipped `{ name, path, kind }` shape and `rules` the compiled list.
   - Only `kind == "file"` entries take part. Folders and links to folders never nest.
   - Rules are walked in list order. For a pattern rule, every file that matches `parent` (in name order) proposes each present file that matches one of its child templates. For a Lua rule, the returned map is walked in parent name order.
   - A proposal (P, C) is accepted when all of these hold:
     - C is not claimed yet;
     - P ≠ C;
     - P is not C and does not descend from C.
     So the first rule wins, and a cycle is broken in favour of the earlier rule.
   - Each accepted child is listed under its top parent: follow parents until one has none. Chains end at the root, as in VS Code.
   - Children are sorted in the tree's name order (`file-tree-view`'s comparator). The result holds only parents with at least one child.
   - A substituted child is a hash lookup in the folder's name table, not a scan. The model caches the map by the `fs.scan` table in a weak-key table plus a settings generation bumped by reload. Git-only redraws reuse the same map and never rerun a Lua rule.
   - The 16 default rules over 5000 files complete within 50 ms after warm-up. The tree's 5000-row caps count visible nest children as well as ordinary rows.
4. **Programmable rules.**
   - A rule `{ "lua": "<module>" }` is resolved with `pcall(require, module)`, which must return `fun(dir: string, names: string[]): table<string, string[]>`.
   - It is called per folder listing with the absolute folder path and its file names in name order.
   - Unknown names, a parent naming itself, and claims already taken are dropped by Decision 3's acceptance rule.
   - Load failure, a raised error or a non-table return skips the rule with the same WARN, and the rest still apply. A warning is shown once per rule per load, not per folder.
   - The user keeps such modules anywhere on the runtimepath, for example `lua/gleb/file_tree/rules/<name>.lua`. Their place in the list is their priority.
5. **Default rule set.** The shipped file, in this order (`.+%.mk` stands for `*.mk`, `README.*` for `README*`):

   | # | parent | children |
   |---|---|---|
   | 1 | `(.+)%.go` | `${capture}_test%.go`, `${capture}_mock%.go`, `${capture}_string%.go` |
   | 2 | `(.+)%.proto` | `${capture}%.pb%.go`, `${capture}_grpc%.pb%.go` |
   | 3 | `go%.mod` | `go%.sum` |
   | 4 | `go%.work` | `go%.work%.sum` |
   | 5 | `(.+)%.ts` | `${capture}%.test%.ts`, `${capture}%.spec%.ts`, `${capture}%.d%.ts`, `${capture}%.js`, `${capture}%.d%.ts%.map` |
   | 6 | `(.+)%.tsx` | `${capture}%.test%.tsx`, `${capture}%.stories%.tsx`, `${capture}%.module%.css` |
   | 7 | `(.+)%.js` | `${capture}%.js%.map`, `${capture}%.min%.js`, `${capture}%.d%.ts` |
   | 8 | `package%.json` | `package%-lock%.json`, `yarn%.lock`, `pnpm%-lock%.yaml`, `bun%.lock`, `bun%.lockb`, `%.npmrc`, `%.nvmrc` |
   | 9 | `tsconfig%.json` | `tsconfig%..+%.json` |
   | 10 | `(.+)%.py` | `${capture}%.pyi`, `test_${capture}%.py`, `${capture}_test%.py` |
   | 11 | `pyproject%.toml` | `uv%.lock`, `poetry%.lock`, `pdm%.lock`, `requirements.*%.txt`, `setup%.cfg`, `setup%.py`, `%.python%-version` |
   | 12 | `Cargo%.toml` | `Cargo%.lock`, `rust%-toolchain%.toml`, `rustfmt%.toml`, `%.rustfmt%.toml`, `clippy%.toml` |
   | 13 | `(.+)%.lua` | `${capture}_spec%.lua` |
   | 14 | `%.gitignore` | `%.gitattributes`, `%.gitmodules` |
   | 15 | `README.*` | `CHANGELOG.*`, `LICENSE.*` |
   | 16 | `Makefile` | `.+%.mk` |

   - The file also has `"nesting": { "enabled": true, … }` and `"ignore": []`. `file-tree-ignored` fills `ignore`.
   - Consequences of the order, all pinned by scenarios:
     - `price.d.ts` and `price.js` go to `price.ts` (rule 5 before 7), and `price.js.map` follows `price.js` up to `price.ts`.
     - `setup.py` goes to `pyproject.toml`, because rule 10 never claims it.
     - `test_money.py` matches rule 10's parent too, but it is claimed as `money.py`'s child first.
   - The four "Default nesting rules" scenarios plus a case table in `tests/unit/file-tree/test_nesting.lua` cover every child of every rule. A draft of the engine (`agent_nest/proto` in the planning scratchpad, not committed) produced exactly the scenario results.
6. **View.**
   - The model keeps each folder's listing and its cached nest map. It drops nested children from the folder's own rows. Each tab's view keeps `expanded_nests: table<string, true>` keyed by the parent's path relative to the root, separate from `expanded`.
   - Nest state lives only for the view: `expanded.json` is unchanged. It survives refreshes and settings reloads, but reroot and `zM` clear it. `draw()` drops a key when its parent is gone, is not a file, or is now childless.
   - File and folder rename or move migrate matching keys in every view of the root. If a parent loses its last child, the chevron goes away.
   - Rows:
     - A parent row draws `▸`/`▾` (the folder expander glyphs) in the expander column with `FileTreeExpander`. A file without children leaves that column blank, as today.
     - Child rows sit one level deeper (2 columns) with their devicon and name group, and no chevron.
     - Children of a collapsed nest are not in the buffer.
   - Actions (ids and keys from `file-tree-view`):
     - `file_tree.toggle_fold` (`za`) on a parent toggles its nest. On a child, it collapses the nest and moves the cursor to the parent. A nest is the fold around its children, so this refines `file-tree-view`'s "`za` on a file collapses its folder", which still applies to plain files.
     - `file_tree.close_node` (`h`, `<BS>`): on an expanded parent, collapse. On a child, collapse the nest and move to the parent. Elsewhere, as before.
     - `file_tree.open` (`<CR>`, `o`, `l`) opens a parent's file and never toggles: open and expand stay two keys, as in IntelliJ.
     - `file_tree.unfold_all` (`zR`) also expands every nest of every folder it expands. `file_tree.fold_all` (`zM`) also collapses every nest.
   - One `select_path(path)` helper expands folders, expands a containing nest, then moves the cursor. Follow, reveal, add, rename and paste pass it `fs.normalize`d paths, including under a symlinked `/private/var` root.
   - Ops act on the row's own file only. A child row's target folder is `dirname(row.path)`. Visual `d` over one collapsed parent deletes only that parent. Deleting or moving a parent re-lists its former children as plain rows. A new file that matches a rule joins its nest at the next listing.
7. **Git tint of a parent.**
   - A parent without its own status gets the strongest status among its listed children through a helper shared with `folder_status`'s strength table, including renamed/deleted → modified folding.
   - With its own status, that status is shown.
   - The tint is the same whether the nest is collapsed or expanded, like a folder. So a collapsed nest never hides a change, which is what the user relies on in IntelliJ's tinted folders.
   - Children keep their own colours. A deleted child absent from the folder listing contributes no tint.
8. **Fixture.** `treeproj` in `tests/fixtures/build.sh`, created by `file-tree-view` as the design fixture. This change relies on the following and adds whatever is missing. Branch `feat/tax`, `go.mod` module `example.com/billing`. Tracked and committed:
   - `.github/workflows/ci.yml`, `.gitignore`, `go.mod`, `go.sum`, `Makefile`, `README.md`
   - `cmd/server/main.go`
   - `internal/billing/discount.go`, `discount_test.go`, `invoice.go`, `invoice_test.go`
   - `internal/money/money.go`, `money_test.go`
   - `web/package.json`, `web/package-lock.json`
   - `web/src/cart.tsx`, `price.ts`, `price.test.ts`, `price.d.ts`

   Working state:
   - `internal/billing/invoice.go` (the 28 lines in the render) and `invoice_test.go` are modified, unstaged.
   - `internal/billing/tax.go` and `tax_test.go` are new and staged.
   - `web/src/price.ts` is modified.
   - `notes.md` is untracked.

   The ignored entries of `treeproj` stay listed until `file-tree-ignored`. So the screen scenario, like `file-tree-view`'s, runs on a copy without them, and keeps holding once they are hidden by default. The manifest records the nest map the default rules give each folder.

   The screen test keeps a byte-identical copy of the approved ANSI capture at `tests/screen/file-tree/nest_proposed.ansi`; it never reads the archivable change folder. It asserts the text verbatim and checks real extmark groups rather than a hand-made mask or a self-blessed screenshot.

## Risks / Trade-offs

- **Pattern footguns.** `-` is a quantifier in Lua patterns (`package-lock` must be `package%-lock`). The default file shows the escapes, and a bad pattern fails quietly as "no match". The design accepts this for the first iteration, as the user asked.
- **Name order coupling.** Children use `file-tree-view`'s comparator (case-insensitive). If it changes, the scenario lists change with it.
- **Re-listing cost.** Nesting runs only for a new `fs.scan` table or settings generation; weak cache keys release old scans.
- **Function rules** run user code on cache misses. Errors are caught, but a slow function slows that listing. There is no timeout.
- **One parent per file** differs from VS Code, which lists a shared child under every parent. The trade is exact ops targets.

## Renders

- Stand-ins: `▸ ▾` expander and nest chevron, `■ □` folder closed/open, `◆` devicon, `⎇` branch.
- The real-glyph, real-colour renders are `renders/nest_current.ansi` and `renders/nest_proposed.ansi`; view them with `command cat`. They are generated by `tree_gen.py` with every cell annotated with its group.
- `FileTree*` groups come from `file-tree-view` (this change adds none). Until it lands, `make colorize` shows them as plain text.
- The Proposed render equals the approved screen `nest_chevron.ansi` cell for cell, except the statusline filetype, which reads `gleb-file-tree` (proposal, Agent decisions).

**Current — tree without nesting**: `100x30`, Normal, tree focused, `treeproj` fixture copy without its ignored entries, on `feat/tax` (Decision 8), `cmd/server`, `internal/billing` and `web/src` expanded, cursor on `invoice.go`, right window `internal/billing/invoice.go` at line 17. The tree of `file-tree-view`: every file is its own row.

```text
                                     ◆ invoice.go                                                   
 ▾ □ billing  ~/work/billing       ┃   1 package billing                                            
   ▸ ■ .github/workflows           ┃   2                                                            
   ▾ □ cmd/server                  ┃   3 import (                                                   
       ◆ main.go                   ┃   4     "fmt"                                                  
   ▾ □ internal                    ┃   5                                                            
     ▾ □ billing                   ┃   6     "example.com/billing/internal/money"                   
         ◆ discount.go             ┃   7 )                                                          
         ◆ discount_test.go        ┃   8                                                            
         ◆ invoice.go              ┃   9 // Invoice is a list of line amounts in cents.             
         ◆ invoice_test.go         ┃  10 type Invoice struct {                                      
         ◆ tax.go                  ┃  11     ID    string                                           
         ◆ tax_test.go             ┃  12     Lines []int                                            
     ▸ ■ money                     ┃  13     Tax   Rate                                             
   ▾ □ web                         ┃  14 }                                                          
     ▾ □ src                       ┃  15                                                            
         ◆ cart.tsx                ┃  16 // Total sums the lines and applies the tax rate.          
         ◆ price.d.ts              ┃  17 func (i Invoice) Total() int {                             
         ◆ price.test.ts           ┃  18     total := 0                                             
         ◆ price.ts                ┃  19     for _, cents := range i.Lines {                        
       ◆ package-lock.json         ┃  20         total += cents                                     
       ◆ package.json              ┃  21     }                                                      
     ◆ .gitignore                  ┃  22     return i.Tax.Apply(total)                              
     ◆ go.mod                      ┃  23 }                                                          
     ◆ go.sum                      ┃  24                                                            
     ◆ Makefile                    ┃  25 // Due renders the total as dollars.                       
     ◆ notes.md                    ┃  26 func (i Invoice) Due() string {                            
     ◆ README.md                   ┃  27     return fmt.Sprintf("due %s", money.Format(i.Total()))  
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
.........c.lllllllllll.............hiiiii...........................................................
.........c.llllllllllllllll........hiiiii...........................................................
oooooooooconnnnnnnnnnoooooooooooooohiiiiipp.ppppppp.pp.p.pppp.pp.pppp.ppppppp.pp.pppppp.............
.........c.nnnnnnnnnnnnnnn.........hiiiiijjjj.qqqqqqq.jjjjjj........................................
.........c.rrrrrr..................hiiiii....qq....qqqqqq...........................................
.........c.rrrrrrrrrrr.............hiiiii....qqqqq...qqq............................................
.....d.e.kkkkk.....................hiiiii....qqq...qqqq.............................................
...d.e.nnn.........................hiiiii...........................................................
.....d.e.nnn.......................hiiiii...........................................................
.........s.llllllll................hiiiiipp.ppppp.pppp.ppp.ppppp.ppp.ppppppp.ppp.ppp.ppppp..........
.........t.llllllllll..............huuuuujjjj....qqqqqqq..vvvvv...qqq...............................
.........t.lllllllllllll...........hiiiii.............w.............................................
.........t.nnnnnnnn................hiiiii....jjj.............jjjjj...qqqqq..........................
.......x.lllllllllllllllll.........hiiiii...........................................................
.......y.llllllllllll..............hiiiii...........................................................
.....z.llllllllll..................hiiiii....jjjjjj...qqq.vvvvv.....................................
.....A.llllll......................hiiiii...........................................................
.....B.llllll......................hiiiii...........................................................
.....C.llllllll....................hiiiiipp.ppp.ppppppp.ppp.ppppp.pp.pppppppp.......................
.....D.EEEEEEEE....................hiiiiijjjj....qqqqqqq..vvv...qqqqqq..............................
.....F.lllllllll...................hiiiii....jjjjjj.....vvvvvvv.mmmm.mmm........vvvvvv...vvvvv......
...................................hiiiii...........................................................
GGGGGGGGHIIIIIIIIIIIHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHIIIIIIIIIIIIIIIIH
```

Legend: `a` [BufferLineFill] · `b` [BufferLineBufferSelected] · `c` [DevIconGo] · `d` [FileTreeExpander] · `e` [FileTreeFolderIcon] · `f` [FileTreeRoot] · `g` [FileTreeRootPath] · `h` [WinSeparator] · `i` [LineNr] · `j` [@keyword] · `k` [FileTreeFolderName] · `l` [FileTreeFileName] · `m` [@string] · `n` [FileTreeGitModified] · `o` [FileTreeCursorLine] · `p` [@comment] · `q` [@type] · `r` [FileTreeGitAdded] · `s` [DevIconTsx] · `t` [DevIconTypeScript] · `u` [CursorLineNr] · `v` [@function.call] · `w` [@number] · `x` [DevIconPackageLockJson] · `y` [DevIconPackageJson] · `z` [DevIconGitIgnore] · `A` [DevIconGoMod] · `B` [DevIconGoSum] · `C` [DevIconMakefile] · `D` [DevIconMd] · `E` [FileTreeGitUntracked] · `F` [DevIconReadme] · `G` [lualine_a_normal] · `H` [lualine_c_normal] · `I` [lualine_b_normal] · `.` [Normal]

**Proposed — nests under a chevron**: `100x30`, Normal, tree focused, `treeproj` fixture copy without its ignored entries, on `feat/tax` (Decision 8), `cmd/server`, `internal/billing` and `web/src` expanded, cursor on `invoice.go`, right window `internal/billing/invoice.go` at line 17; default rules, the `invoice.go` nest expanded, the others collapsed. Equals the approved `nest_chevron` screen.

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
