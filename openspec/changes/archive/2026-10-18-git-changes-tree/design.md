## Context

See proposal.md. Today `<A-G>` opens neo-tree's `git_status` source (`lua/gleb/file_tree/actions.lua`): `j`/`k` skip folders and open a second tab with codediff and a copy of the tree in it, a 300 ms focus guard pulls focus back, `<space>` stages, `A` stages all, `X` reverts, `gc` commits through the AI popup, `P` pushes (Current A and B below). `<A-g>` opens differ.nvim with its own file panel. The user picked IntelliJ's commit tree instead (decision page, "Changes panel"), shown next to the IntelliJ-style diff view of `diff-view`/`diff-view-actions`.

IntelliJ's commit tool window (`ChangesListView`, `ChangesBrowserNode*` in the platform `vcs-impl` module): roots per change list plus "Unversioned Files"; "Group by directory" with compacted middle folders; a checkbox per node that includes it in the commit (tri-state on folders and roots); selecting a node shows its diff in the editor area; Rollback (`Ctrl+Alt+Z`) asks before reverting, keeps an added file on disk unless "delete local copies" is ticked, and is disabled for unversioned files. In git's staging-area mode the checkbox is the index, which is what the user asked for ("checkbox = staged").

## Goals / Non-Goals

**Goals:**
- The approved panel (`ch_idea`), driven by git's porcelain output, with the diff view of `diff-view` in the editor area.
- Every behaviour of the neo-tree `git_status` source carried over: exact-path staging independent of the cwd, argument-list git calls, the same error texts, the revert prompt, the AI commit, the push notifications, focus staying in the panel, one reused diff view, debounced and stale-safe.
- Coexistence: nothing existing changes; `changes.toggle` and `changes.review` are unbound until `tree-diff-cutover`.

**Non-Goals:**
- Hunk or line staging (the diff view's per-change checkbox, `diff-view-actions`).
- Change lists, shelving, amend, partial commits of unstaged content, commit message history.
- A "Merge Conflicts" root: unmerged files are listed under `Changes` in `FileTreeGitConflict`; merges stay in diffview.
- Removing neo-tree, differ or codediff (`tree-diff-cutover`).

## Decisions

1. **Modules** (rules 1.1–1.5, 1.9). `lua/gleb/git/changes/`:
   - `model.lua` (pure, rule 1.3): consumes `gleb.file_tree.model.parse_status_records`, parses `git diff --numstat -z HEAD`, and builds the row tree (roots, directory groups, compaction, nests, sort, fold ids) in one grouping pass. Nests come from `gleb.file_tree.nesting.nest(dir, entries, rules)` with the explicitly loaded default rules of `gleb.file_tree.settings` (`file-tree-nesting`).
   - `render.lua` (pure): rows → buffer lines and highlight spans for a width.
   - `git.lua`: every git call through `vim.system` with an argument list and `cwd = root` (rule 6.4); async results go through `vim.schedule` and are dropped when the panel's refresh generation moved on (rule 6.3).
   - `view.lua`: window, buffer, cursor, folds, scoped autocmds (`gleb_changes`), per-panel debounce timer and generations, diff-view link. `M.state.by_tab` + `M.reset()` live in `init.lua`.
   - `actions.lua`: the `changes.*` actions; `lua/gleb/git/actions.lua` appends them and `lua/gleb/git/init.lua` loads the changes module after gitlink.
   - `highlights.lua`: `Changes*` groups from the palette helpers, re-applied on `ColorScheme` (rule 8.7).
2. **Status.** `gleb.file_tree.model.parse_status_records(z)` parses porcelain v2 once into ordered `{ kind, xy, sub, path, orig }` records, consuming the extra NUL field of `2` records. `parse_status` and the ignored set remain compatibility wrappers. `R` and `C` are renamed with `orig` retained, `.A` is added, and `u` is conflict. The same path may appear under both roots. `? dir/` and records whose submodule field starts with `S` are leaf rows with no diff, no buffer load and no `<CR>`; selecting or opening one notifies. Status uses `git --no-optional-locks`, and rows are capped at the project-tree limit.
3. **Stats.** `git diff --numstat -z HEAD` covers index and worktree against `HEAD` in one call; a rename record (`a\tb\t\0old\0new\0`) is keyed by the new path; `-\t-` (binary) shows nothing; an unborn `HEAD` skips the call, so no row has stats.
4. **Staging decision on fresh status.** Every git call starts with `git --literal-pathspecs`. `<Space>` makes one fresh `git status --porcelain=v2 -z -- <paths>` decision for the selected file, directory or root, never from row state or one process per file. Above 100 paths it sends NUL paths through `--pathspec-from-file=- --pathspec-file-nul`. It stages unless every selected change is staged. Rename unstaging resets both new and old paths. An unmerged file notifies `Stage failed: resolve conflicts in the merge tool` and runs no mutation; `A` still runs `git add -A`.
5. **Layout** (from the approved render, 2 columns per depth): a row of depth `d` has its expander at column `1+2d`, a file's checkbox at `3+2d`, icon at `5+2d` and name at `7+2d`; a directory has no checkbox, its folder icon at `3+2d`, its name at `5+2d` and then its file count in `ChangesCount`; a root has expander, checkbox, bold label and grey count. Stats end in the last column after one space; a name that would touch them is cut and ends with `…` (`ChangesCount`). Sort: directories before files, case-insensitive name order, ties by bytes. Nests start expanded (the approved render shows both open; the project tree's start collapsed). Fold ids: `changes`, `unversioned`, `<root>:<dir>`, `<root>:<dir>/<name>`.
6. **Diff view link** (`diff-view`'s embedding API). After a 50 ms per-panel debounce, the panel asynchronously builds the full `gleb.diff.view.Spec`: normalized root, repo-relative `relpath`, filetype, `head_final_newline`, left text from `HEAD:<orig or path>`, and the working-tree side. Root and selection generations drop stale work; selecting the same path does not call `show` again. Added, untracked, deleted, binary, unmerged and submodule files are not actionable. Deleted and binary content uses read-only buffers and never `bufadd`; buffers loaded only by the panel are unloaded on close when unmodified. If `show` returns nil, only the panel's previous view closes and `No content changes: <name>` is notified.
7. **`changes.review`** is the review entry point (`tree-diff-cutover` binds it to Cmd+G in place of differ): open or focus the panel and show the selected row's diff at once. `changes.toggle` only opens the panel, like `<A-G>` today, and the editor keeps its buffer until the cursor moves.
8. **`diff.next_file` from the panel.** The panel passes `on_next_file`: it moves the panel cursor to the next file row and shows it at once (no debounce); on the last row nothing changes. When invoked from a diff window, completion focuses the replacement view's `right_win`. This replaces differ's `]f`.
9. **Revert.** The existing prompt text and `y` confirmation stay. Every command uses literal pathspecs. A tracked file uses `checkout HEAD`; a rename checks out the old path and removes the new path from the index; a path absent from HEAD, including on unborn HEAD, uses `rm --cached` and stays on disk. Untracked rows do nothing. Failures notify `Revert failed: <stderr>`.
10. **Commit and push** reuse today's code paths and notifications in the panel root. Commit calls `gleb.git.ai_commit.show_commit_input(on_commit, { root = root })`, so staged-diff generation and commit both use that repository.
11. **Refresh** is async and coalesced. It runs after panel git commands, `BufWritePost` under the root, `FocusGained`, and `watch.lua`'s git-dir event, which covers diff-view hunk staging and gitsigns. Every panel git command also calls public `diff.view.refresh_index(view)`. Buffer- or window-scoped autocmds and per-panel timers and generations isolate tabs.
12. **Windows and one left tool window.** State is keyed by tab. Root and buffer paths pass through `fs.normalize`. The project tree exports its eligible-editor helper with `gleb-changes` excluded; the panel revalidates the editor before every `show`. `QuitPre` and orphan-close mirror the file tree. The panel owns and closes only its own diff handle; editor-buffer restoration stays in `windows.restore`. Opening one left tool window closes the other, and both stay 35 columns.
13. **Keys and actions** (rule 3.1): `settings/keymap.json` gains `changes.toggle_stage` `<Space>`, `changes.stage_all` `A`, `changes.open` `<CR>`, `changes.revert` `X`, `changes.commit` `gc`, `changes.push` `P`, `changes.close` `q`, `changes.toggle_fold` `za`, all `ft = "gleb-changes"`, category `Changes`, with no `plugin`. `changes.toggle` ("Toggle Changes") and `changes.review` ("Review Changes"), category `View | Tool Windows`, are added to Find Action's approved catalog list and get no key here. `<CR>` on a root or directory row runs `changes.toggle_fold`'s behaviour.
14. **Fixture** `billing` (below) is added to `tests/fixtures/build.sh`; its numbers are the approved render's. `dirty` is reused for the logic scenarios.

## Fixture

`tests/fixtures/build.sh billing` (header line: `build.sh billing  Go/TS repo with staged, unstaged and untracked changes (changes panel)`). Commits are dated by the script's fixed env, so `HEAD` is `4ccefde`. Result: `invoice.go` +12 -3, `invoice_test.go` +20 -1 (unstaged), `tax.go` +41 -0, `tax_test.go` +33 -0 (staged new), `web/src/price.ts` +4 -4 (unstaged), `notes.md` untracked (9 lines).

```sh
billing() {
	git init -q
	mkdir -p cmd/server internal/billing internal/money web/src
	printf 'module example.com/billing\n\ngo 1.23\n' >go.mod
	printf 'bin/\n.env\nnode_modules/\n' >.gitignore
	printf '# billing\n\nInvoices, tax and prices.\n' >README.md
	printf 'test:\n\tgo test ./...\n' >Makefile
	cat >cmd/server/main.go <<'GO'
package main

func main() {}
GO
	cat >internal/money/money.go <<'GO'
package money

import "fmt"

// Format renders cents as dollars.
func Format(cents int) string {
	return fmt.Sprintf("$%d.%02d", cents/100, cents%100)
}
GO
	cat >internal/billing/invoice.go <<'GO'
package billing

import (
	"fmt"

	"example.com/billing/internal/money"
)

// Invoice is a list of line amounts in cents.
type Invoice struct {
	ID    string
	Lines []int
	Tax   Rate
}

// Total sums the lines and applies the tax rate.
func (i Invoice) Total() int {
	total := 0
	for _, cents := range i.Lines {
		total += cents
	}
	return i.Tax.Apply(total)
}

// Due renders the total as dollars.
func (i Invoice) Due() string {
	return fmt.Sprintf("due %s", money.Format(i.Total()))
}
GO
	cat >internal/billing/invoice_test.go <<'GO'
package billing

import "testing"

func TestTotal(t *testing.T) {
	inv := Invoice{Lines: []int{100, 250}}
	if inv.Total() != 350 {
		t.Fatal("total")
	}
}
GO
	cat >web/src/price.ts <<'TS'
export type Price = { cents: number; currency: string };

export function format(price: Price): string {
  const units = price.cents / 100;
  return `${units} ${price.currency}`;
}

export function add(a: Price, b: Price): Price {
  return { cents: a.cents + b.cents, currency: a.currency };
}
TS
	printf 'export function Cart() {\n  return null;\n}\n' >web/src/cart.tsx
	commit "billing: invoices and prices"
	# unstaged edits: invoice.go +12 -3, invoice_test.go +20 -1, price.ts +4 -4
	cat >internal/billing/invoice.go <<'GO'
package billing

import (
	"fmt"

	"example.com/billing/internal/money"
)

// Invoice is a list of line amounts in cents, with a tax rate.
type Invoice struct {
	ID    string // invoice number
	Lines []int
	Tax   Rate
}

// Total sums the lines and applies the tax rate.
func (i Invoice) Total() int {
	var total int
	for _, cents := range i.Lines {
		total += cents
	}
	if i.Tax == nil {
		return total
	}
	return i.Tax.Apply(total)
}

// Due renders the total as dollars.
func (i Invoice) Due() string {
	return fmt.Sprintf("due %s", money.Format(i.Total()))
}

// Paid reports whether nothing is due.
func (i Invoice) Paid() bool {
	total := i.Total()
	return total == 0
}
GO
	cat >internal/billing/invoice_test.go <<'GO'
package billing

import "testing"

func TestTotal(t *testing.T) {
	inv := Invoice{Lines: []int{100, 250}}
	if got := inv.Total(); got != 350 {
		t.Fatal("total")
	}
}

func TestDue(t *testing.T) {
	inv := Invoice{Lines: []int{100, 250}}
	if got := inv.Due(); got != "due $3.50" {
		t.Fatalf("due = %q", got)
	}
}

func TestPaid(t *testing.T) {
	if !(Invoice{}).Paid() {
		t.Fatal("empty invoice is paid")
	}
}

func TestTaxNil(t *testing.T) {
	if got := (Invoice{Lines: []int{100}}).Total(); got != 100 {
		t.Fatalf("total = %d", got)
	}
}
GO
	cat >web/src/price.ts <<'TS'
export type Price = { cents: number; currency: "EUR" | "USD" };

export function format(price: Price): string {
  const units = (price.cents / 100).toFixed(2);
  return `${units} ${price.currency.toLowerCase()}`;
}

export function add(a: Price, b: Price): Price {
  return { ...a, cents: a.cents + b.cents };
}
TS
	# staged new files: tax.go +41, tax_test.go +33
	{
		printf 'package billing\n\n'
		printf '// Rate applies a tax to an amount in cents.\ntype Rate interface {\n\tApply(cents int) int\n}\n'
		for name in Flat Percent Exempt; do
			printf '\n// %s is a %s tax rate.\ntype %s struct {\n\tValue int\n}\n' "$name" "$name" "$name"
			printf '\n// Apply implements Rate.\nfunc (r %s) Apply(cents int) int {\n\treturn cents + r.Value\n}\n' "$name"
		done
		printf '\n// Rates lists every known rate.\nvar Rates = []Rate{\n\tFlat{}, Percent{}, Exempt{},\n}\n'
	} >internal/billing/tax.go
	{
		printf 'package billing\n\nimport "testing"\n'
		for name in Flat Percent Exempt; do
			printf '\nfunc Test%s(t *testing.T) {\n\trate := %s{Value: 5}\n\tif got := rate.Apply(100); got != 105 {\n\t\tt.Fatalf("%s = %%d", got)\n\t}\n\t_ = Invoice{Tax: rate}\n\t_ = rate\n\t_ = t\n}\n' "$name" "$name" "$name"
		done
	} >internal/billing/tax_test.go
	git add internal/billing/tax.go internal/billing/tax_test.go
	# untracked: notes.md (9 lines)
	printf '# Notes\n\n- tax rates per region\n- invoice numbering\n- rounding of cents\n\nOpen questions:\n- refunds\n- currencies\n' >notes.md
	staged=$(git diff --cached --name-only | file_entries true false)
	unstaged=$(git diff --name-only | file_entries false false)
	untracked=$(git ls-files --others --exclude-standard | file_entries false true)
	printf '{"files":[%s,%s,%s]}\n' "$staged" "$unstaged" "$untracked" >../manifest.json
}
```

## Renders

Stand-ins: `☐ ☑ ◪` checkbox empty / checked / mixed, `■ □` folder, `▸ ▾` expander, `◆` devicon, `»` apply arrow, `╱` padding, `~` fold row. The real-glyph, real-colour renders are in `renders/*.ansi` (view with `command cat`). Current A and B are real captures (`tests/render/tmux.lua` driven by a planning script on the `billing` fixture, masks resolved from the captured colours). Proposed A and B are mockups from the approved generators (`tree_gen.py` `changes_idea`, `diff_gen.py` aligned), every cell annotated with its group. Check them with `make colorize FILE=openspec/changes/git-changes-tree/design.md CASE=neo-tree` (the case loads neo-tree's groups). It reports as unknown the new groups (`Changes*`, and `FileTree*`/`DiffView*` until `file-tree-view` and `diff-view` land) and three that exist only on first use: `CodeDiffCharInsert` and `CodeDiffFiller` (after codediff loads) and `DevIconTs` (nvim-web-devicons creates it when a `.ts` icon is first drawn).

**Current A — git status tree**: `100x30`, Normal, `billing` fixture, `internal/billing/invoice.go` open, `:Neotree git_status`, cursor on `invoice.go` (real capture).

```text
                                          ◆ invoice.go                                              
 □ GIT STATUS for /private/var/fold┃  1   package billing                                           
 ▾ ◆ □ internal                    ┃    1                                                           
   ▾ ◆ □ billing                   ┃    2 import (                                                  
     │ ◆   ◆ invoice.go            ┃    3 ▏ "fmt"                                                   
     │ ◆   ◆ invoice_test.go       ┃    4 ▏                                                         
     │ ✚ » ◆ tax.go                ┃    5 ▏ "example.com/billing/internal/money"                    
     └ ✚ » ◆ tax_test.go           ┃    6 )                                                         
 ▾ ◆ □ web                         ┃    7                                                           
   ▾ ◆ □ src                       ┃┃   8 // Invoice is a list of line amounts in cents, with a tax 
     └ ◆   ◆ price.ts              ┃    9 type Invoice struct {                                     
   ? ◆ notes.md                    ┃┃  10 ▏ ID    string // invoice number                          
                                   ┃   11 ▏ Lines []int                                             
                                   ┃   12 ▏ Tax   Rate                                              
                                   ┃   13 }                                                         
                                   ┃   14                                                           
                                   ┃   15 // Total sums the lines and applies the tax rate.         
                                   ┃   16 func (i Invoice) Total() int {                            
                                   ┃┃  17 ▏ var total int                                           
                                   ┃   18 ▏ for _, cents := range i.Lines {                         
                                   ┃   19 ▏ ▏ total += cents                                        
                                   ┃   20 ▏ }                                                       
                                   ┃┃  21 ▏ if i.Tax == nil {                                       
                                   ┃┃  22 ▏ ▏ return total                                          
                                   ┃┃  23 ▏ }                                                       
                                   ┃   24 ▏ return i.Tax.Apply(total)                               
                                   ┃   25 }                                                         
                                   ┃   26                                                           
                                   ┃   27 // Due renders the total as dollars.                      
 NORMAL  ⎇ main                                                               ◆ 0 ◆ 0 ◆ ◆ neo-tree ◆
```

```text
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabcccccddcccccccccccccccceeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
.ffggggggggggggggggggggggggggggggggh..iiiijjjjjjj...................................................
kkkllffmmmmmmmm....................h..iiii..........................................................
...kkllffmmmmmmm...................h..iiiijjjjjj....................................................
nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnh..iiiiiiooooo...................................................
.....ppllqqddlllllllllllllll.......h..iiiii.........................................................
.....ppmmqqddmmmmmm................h..iiiiiioooooooooooooooooooooooooooooooooooo....................
.....ppmmqqddmmmmmmmmmmm...........h..iiii..........................................................
kkkllffmmm.........................h..iiii..........................................................
...kkllffmmm.......................hrriiiissssssssssssssssssssssssssssssssssssssssssssssssssssssssss
.....ppllqqaallllllll..............h..iiiijjjj.ttttttt.jjjjjj.......................................
...uuvvuuuuuuuu....................hrriiiiiitt....wwwwww.sssssssssssssssss..........................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaah..iiiiiittttt...www.............................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaah..iiiiiittt...wwww..............................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaah..iiii..........................................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaah..iiii..........................................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaah..iiiisssssssssssssssssssssssssssssssssssssssssssssssss.........
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaah..iiiijjjj....wwwwwww..rrrrr...www..............................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaahrriiiiiijjj.ttttt.www...........................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaah..iiiiiijjj.to.ttttt.jj.jjjjj.toxxxxx...........................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaah..iiiiiiiittttt.jj.ttttt........................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaah..iiiiii........................................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaahwwiiiiiijj.toxxx.jj.xxx.........................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaahwwiiiiiiiijjjjjj.ttttt..........................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaahwwiiiiii........................................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaah..iiiiiijjjjjj.toxxxorrrrr.ttttt................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaah..iiii..........................................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaah..iiii..........................................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaah..iiiissssssssssssssssssssssssssssssssssss......................
yyyyyyyyzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzAAAAABBBBCDEDDDDDDDDDDF
```

Legend: `a` [NeoTreeNormal] · `b` [BufferLineIndicatorVisible] · `c` [BufferLineBufferVisible] · `d` [DevIconGo] · `e` [BufferLineFill] · `f` [NeoTreeDirectoryIcon] · `g` [NeoTreeRootName] · `h` [WinSeparator] · `i` [LineNr] · `j` [@keyword] · `k` [NeoTreeExpander] · `l` [NeoTreeGitModified] · `m` [NeoTreeDirectoryName] · `n` [NeoTreeCursorLine] · `o` [@string] · `p` [NeoTreeIndentMarker] · `q` [NeoTreeGitStaged] · `r` [@function] · `s` [@comment] · `t` [@type.definition] · `u` [NeoTreeGitUntracked] · `v` [DevIconMd] · `w` [@function.call] · `x` [@property] · `y` [lualine_a_normal] · `z` [lualine_b_normal] · `A` [lualine_x_diagnostics_error_command] · `B` [lualine_x_diagnostics_warn_command] · `C` [StatuslineLangCapError] · `D` [StatuslineLangText] · `E` [StatuslineLang_neo_tree] · `F` [StatuslineLangEdge] · `.` [Normal]

**Current B — diff preview tab**: `100x30`, same state, then `j` onto `invoice.go`: a second tab with codediff and the tree reopened in it (real capture).

```text
                                          ◆ invoice.go      ▏      ◆ invoice.go           ▏ 1 ▕▏ 2 ▕
 □ GIT STATUS for /private/var/fold┃    8 package┃    8 package billing                             
 ▾ ◆ □ internal                    ┃    7        ┃    7                                             
   ▾ ◆ □ billing                   ┃    6 import ┃    6 import (                                    
     │ ◆   ◆ invoice.go            ┃    5   "fmt"┃    5 ▏ "fmt"                                     
     │ ◆   ◆ invoice_test.go       ┃    4        ┃    4 ▏                                           
     │ ✚ » ◆ tax.go                ┃    3   "exam┃    3 ▏ "example.com/billing/internal/money"      
     └ ✚ » ◆ tax_test.go           ┃    2 )      ┃    2 )                                           
 ▾ ◆ □ web                         ┃    1        ┃    1                                             
   ▾ ◆ □ src                       ┃  9   // Invo┃┃ 9   // Invoice is a list of line amounts in cent
     └ ◆   ◆ price.ts              ┃    1 type In┃    1 type Invoice struct {                       
   ? ◆ notes.md                    ┃    2   ID   ┃┃   2 ▏ ID    string // invoice number            
                                   ┃    3   Lines┃    3 ▏ Lines []int                               
                                   ┃    4   Tax  ┃    4 ▏ Tax   Rate                                
                                   ┃    5 }      ┃    5 }                                           
                                   ┃    6        ┃    6                                             
                                   ┃    7 // Tota┃    7 // Total sums the lines and applies the tax 
                                   ┃    8 func (i┃    8 func (i Invoice) Total() int {              
                                   ┃    9   total┃┃   9 ▏ var total int                             
                                   ┃   10   for _┃   10 ▏ for _, cents := range i.Lines {           
                                   ┃   11     tot┃   11 ▏ ▏ total += cents                          
                                   ┃   12   }    ┃   12 ▏ }                                         
                                   ┃      ╱╱╱╱╱╱╱┃┃  13 ▏ if i.Tax == nil {                         
                                   ┃      ╱╱╱╱╱╱╱┃┃  14 ▏ ▏ return total                            
                                   ┃      ╱╱╱╱╱╱╱┃┃  15 ▏ }                                         
                                   ┃   13   retur┃   16 ▏ return i.Tax.Apply(total)                 
                                   ┃   14 }      ┃   17 }                                           
                                   ┃   15        ┃   18                                             
                                   ┃   16 // Due ┃   19 // Due renders the total as dollars.        
 NORMAL  ⎇ main                                                               ◆ 0 ◆ 0 ◆ ◆ neo-tree ◆
```

```text
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabcccccddccccccccccccccccebcccccddccccccccccccccccfffffghhhgijjji
.kkllllllllllllllllllllllllllllllllm..nnnnooooooom..nnnnooooooo.....................................
pppqqkkrrrrrrrr....................m..nnnn.......m..nnnn............................................
...ppqqkkrrrrrrr...................m..nnnnoooooo.m..nnnnoooooo......................................
sssssssssssssssssssssssssssssssssssm..nnnn..tttttm..nnnnnnttttt.....................................
.....uuqqvvddqqqqqqqqqqqqqqq.......m..nnnn.......m..nnnnn...........................................
.....uurrvvddrrrrrr................m..nnnn..tttttm..nnnnnntttttttttttttttttttttttttttttttttttt......
.....uurrvvddrrrrrrrrrrr...........m..nnnn.......m..nnnn............................................
pppqqkkrrr.........................m..nnnn.......m..nnnn............................................
...ppqqkkrrr.......................m..wwwwxxxxxxxmyywwwwxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
.....uuqqvvaaqqqqqqqq..............m..nnnnoooo.zzm..nnnnoooo.zzzzzzz.oooooo.........................
...AABBAAAAAAAA....................m..nnnnCCCCCCCmyynnnnDDDDDDDDDDDDDDExxxxxxxxxxxxxxxxxDDDDDDDDDDDD
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaam..nnnn..zzzzzm..nnnnnnzzzzz...FFF...............................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaam..nnnn..zzz..m..nnnnnnzzz...FFFF................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaam..nnnn.......m..nnnn............................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaam..nnnn.......m..nnnn............................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaam..nnnnxxxxxxxm..nnnnxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaam..nnnnoooo...m..nnnnoooo....FFFFFFF..yyyyy...FFF................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaam..nnnnCCCCCCCmyynnnnDDEEEEDDDDDDEEEDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaam..nnnn..ooo.zm..nnnnnnooo.zt.zzzzz.oo.ooooo.ztGGGGG.............
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaam..nnnn....zzzm..nnnnnnnnzzzzz.oo.zzzzz..........................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaam..nnnn.......m..nnnnnn..........................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaam..nnnnHHHHHHHmFFnnnnEEEEEEEEEEEEEEEEEEEDDDDDDDDDDDDDDDDDDDDDDDDD
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaam..nnnnHHHHHHHmFFnnnnEEEEEEEEEEEEEEEEDDDDDDDDDDDDDDDDDDDDDDDDDDDD
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaam..nnnnHHHHHHHmFFnnnnEEEDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaam..nnnn..ooooom..nnnnnnoooooo.ztGGGtyyyyy.zzzzz..................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaam..nnnn.......m..nnnn............................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaam..nnnn.......m..nnnn............................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaam..nnnnxxxxxxxm..nnnnxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx........
IIIIIIIIJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJKKKKKLLLLMNONNNNNNNNNNP
```

Legend: `a` [NeoTreeNormal] · `b` [BufferLineIndicatorVisible] · `c` [BufferLineBufferVisible] · `d` [DevIconGo] · `e` [BufferLineSeparator] · `f` [BufferLineFill] · `g` [BufferLineTabSeparator] · `h` [BufferLineBuffer] · `i` [BufferLineTabSeparatorSelected] · `j` [BufferLineTabSelected] · `k` [NeoTreeDirectoryIcon] · `l` [NeoTreeRootName] · `m` [WinSeparator] · `n` [LineNr] · `o` [@keyword] · `p` [NeoTreeExpander] · `q` [NeoTreeGitModified] · `r` [NeoTreeDirectoryName] · `s` [NeoTreeCursorLine] · `t` [@string] · `u` [NeoTreeIndentMarker] · `v` [NeoTreeGitStaged] · `w` [CursorLineNr] · `x` [@comment] · `y` [@function] · `z` [@type.definition] · `A` [NeoTreeGitUntracked] · `B` [DevIconMd] · `C` [DiffDelete] · `D` [DiffAdd] · `E` [CodeDiffCharInsert] · `F` [@function.call] · `G` [@property] · `H` [CodeDiffFiller] · `I` [lualine_a_normal] · `J` [lualine_b_normal] · `K` [lualine_x_diagnostics_error_command] · `L` [lualine_x_diagnostics_warn_command] · `M` [StatuslineLangCapError] · `N` [StatuslineLangText] · `O` [StatuslineLang_neo_tree] · `P` [StatuslineLangEdge] · `.` [Normal]

**Proposed A — changes panel** (approved `ch_idea`): `100x30`, Normal, `billing` fixture, `internal/billing/invoice.go` edited, then `changes.toggle`; focus in the panel, cursor on `invoice.go`.

```text
                                     ◆ invoice.go                                                   
 ▾ ◪ Changes 5 files               ┃   1 package billing                                            
   ▾ □ internal/billing 4          ┃   2                                                            
     ▾ ☐ ◆ invoice.go       +12 -3 ┃   3 import (                                                   
         ☐ ◆ invoice_test.… +20 -1 ┃   4     "fmt"                                                  
     ▾ ☑ ◆ tax.go           +41 -0 ┃   5                                                            
         ☑ ◆ tax_test.go    +33 -0 ┃   6     "example.com/billing/internal/money"                   
   ▾ □ web/src 1                   ┃   7 )                                                          
       ☐ ◆ price.ts          +4 -4 ┃   8                                                            
 ▾ ☐ Unversioned Files 1 file      ┃   9 // Invoice is a list of line amounts in cents, with a tax r
     ☐ ◆ notes.md                  ┃  10 type Invoice struct {                                      
                                   ┃  11     ID    string // invoice number                         
                                   ┃  12     Lines []int                                            
                                   ┃  13     Tax   Rate                                             
                                   ┃  14 }                                                          
                                   ┃  15                                                            
                                   ┃  16 // Total sums the lines and applies the tax rate.          
                                   ┃  17 func (i Invoice) Total() int {                             
                                   ┃  18     var total int                                          
                                   ┃  19     for _, cents := range i.Lines {                        
                                   ┃  20         total += cents                                     
                                   ┃  21     }                                                      
                                   ┃  22     if i.Tax == nil {                                      
                                   ┃  23         return total                                       
                                   ┃  24     }                                                      
                                   ┃  25     return i.Tax.Apply(total)                              
                                   ┃  26 }                                                          
                                   ┃  27                                                            
                                   ┃  28 // Due renders the total as dollars.                       
 NORMAL  ⎇ main                                                                       gleb-changes  
```

```text
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabcbbbbbbbbbbbbbaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
dedfdgggggggdhhhhhhhdddddddddddddddijjjjjkkkkkkk....................................................
dddedldmmmmmmmmmmmmmmmmdhddddddddddinnnnn...........................................................
oooooeofocoppppppppppoooooooqqqorroinnnnnkkkkkk.....................................................
dddddddddfdcdppppppppppppphdqqqdrrdinnnnn....sssss..................................................
dddddedfdcdttttttdddddddddddqqqdrrdinnnnn...........................................................
dddddddddfdcdtttttttttttddddqqqdrrdinnnnn....ssssssssssssssssssssssssssssssssssss...................
dddedldmmmmmmmdhdddddddddddddddddddinnnnn...........................................................
dddddddfdudppppppppddddddddddqqdrrdinnnnn...........................................................
dedfdgggggggggggggggggdhhhhhhddddddinnnnnvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
dddddfdwdxxxxxxxxddddddddddddddddddinnnnnkkkk.yyyyyyy.kkkkkk........................................
dddddddddddddddddddddddddddddddddddinnnnn....yy....zzzzzz.vvvvvvvvvvvvvvvvv.........................
dddddddddddddddddddddddddddddddddddinnnnn....yyyyy...zzz............................................
dddddddddddddddddddddddddddddddddddinnnnn....yyy...yyyy.............................................
dddddddddddddddddddddddddddddddddddinnnnn...........................................................
dddddddddddddddddddddddddddddddddddinnnnn...........................................................
dddddddddddddddddddddddddddddddddddinnnnnvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv..........
dddddddddddddddddddddddddddddddddddinnnnnkkkk....yyyyyyy..AAAAA...zzz...............................
dddddddddddddddddddddddddddddddddddinnnnn....kkk.......zzz..........................................
dddddddddddddddddddddddddddddddddddinnnnn....kkk.............kkkkk...yyyyy..........................
dddddddddddddddddddddddddddddddddddinnnnn...........................................................
dddddddddddddddddddddddddddddddddddinnnnn...........................................................
dddddddddddddddddddddddddddddddddddinnnnn....kk...yyy....kkk........................................
dddddddddddddddddddddddddddddddddddinnnnn........kkkkkk.............................................
dddddddddddddddddddddddddddddddddddinnnnn...........................................................
dddddddddddddddddddddddddddddddddddinnnnn....kkkkkk...yyy.AAAAA.....................................
dddddddddddddddddddddddddddddddddddinnnnn...........................................................
dddddddddddddddddddddddddddddddddddinnnnn...........................................................
dddddddddddddddddddddddddddddddddddinnnnnvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv.......................
BBBBBBBBCCCCCCCCDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDEEEEEEEEEEEEEED
```

Legend: `a` [BufferLineFill] · `b` [BufferLineBufferSelected] · `c` [DevIconGo] · `d` [FileTreeNormal] · `e` [FileTreeExpander] · `f` [ChangesCheckbox] · `g` [ChangesRoot] · `h` [ChangesCount] · `i` [WinSeparator] · `j` [CursorLineNr] · `k` [@keyword] · `l` [FileTreeFolderIcon] · `m` [FileTreeFolderName] · `n` [LineNr] · `o` [FileTreeCursorLine] · `p` [FileTreeGitModified] · `q` [ChangesStatAdded] · `r` [ChangesStatRemoved] · `s` [@string] · `t` [FileTreeGitAdded] · `u` [DevIconTs] · `v` [@comment] · `w` [DevIconMd] · `x` [FileTreeGitUntracked] · `y` [@type] · `z` [@type.builtin] · `A` [@function] · `B` [lualine_a_normal] · `C` [lualine_b_normal] · `D` [lualine_c_normal] · `E` [StatuslineLangText] · `.` [Normal]

The panel columns (1-36) equal the approved `ch_idea` screen cell for cell, text and colour. The editor shows the fixture's working copy. The tabline offset over the panel is the approved look and the statusline chip names the filetype `gleb-changes` (the mockup said `changes`); the offset for `gleb-changes` arrives with `tree-diff-cutover`, so the screen scenario covers the panel columns only.

**Proposed B — changes panel with the diff view**: `100x30`, Normal, same fixture and file, then `changes.review`; focus in the panel, the editor area shows the diff view of `invoice.go`.

```text
                                     ◆ invoice.go                                                   
 ▾ ◪ Changes 5 files               ┃ 4ccefde · HEAD                           Your version          
   ▾ □ internal/billing 4          ┃~~ 4 unchanged lines ~~~~ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     ▾ ☐ ◆ invoice.go       +12 -3 ┃                             5        5                         
         ☐ ◆ invoice_test.… +20 -1 ┃     "example.com/billing    6        6       "example.com/billi
     ▾ ☑ ◆ tax.go           +41 -0 ┃ )                           7        7   )                     
         ☑ ◆ tax_test.go    +33 -0 ┃                             8        8                         
   ▾ □ web/src 1                   ┃ // Invoice is a list of  »  9        9 ☐ // Invoice is a list o
       ☐ ◆ price.ts          +4 -4 ┃ type Invoice struct {      10       10   type Invoice struct { 
 ▾ ☐ Unversioned Files 1 file      ┃     ID    string         » 11       11 ☐     ID    string // in
     ☐ ◆ notes.md                  ┃     Lines []int            12       12       Lines []int       
                                   ┃     Tax   Rate             13       13       Tax   Rate        
                                   ┃ }                          14       14   }                     
                                   ┃                            15       15                         
                                   ┃ // Total sums the lines    16       16   // Total sums the line
                                   ┃ func (i Invoice) Total()   17       17   func (i Invoice) Total
                                   ┃     total := 0           » 18       18 ☐     var total int     
                                   ┃     for _, cents := rang   19       19       for _, cents := ra
                                   ┃         total += cents     20       20           total += cents
                                   ┃     }                      21       21       }                 
                                   ┃╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱ »╱╱╱╱      22 ☐     if i.Tax == nil { 
                                   ┃╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱  ╱╱╱╱      23           return total  
                                   ┃╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱  ╱╱╱╱      24       }                 
                                   ┃     return i.Tax.Apply(t   22       25       return i.Tax.Apply
                                   ┃ }                          23       26   }                     
                                   ┃                            24       27                         
                                   ┃ // Due renders the total   25       28   // Due renders the tot
                                   ┃ func (i Invoice) Due() s   26       29   func (i Invoice) Due()
                                   ┃     return fmt.Sprintf("   27       30       return fmt.Sprintf
 NORMAL  ⎇ main                                                                       gleb-changes  
```

```text
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabcbbbbbbbbbbbbbaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
dedfdgggggggdhhhhhhhdddddddddddddddijjjjjjjjjjjjjjjjjjjjjjjjjijjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj
dddedkdlllllllllllllllldhddddddddddimmnnnnnnnnnnnnnnnnnnnmmmmimmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm
oooooeofocoppppppppppoooooooqqqorroi.........................i.ssss.....ssss........................
dddddddddfdcdppppppppppppphdqqqdrrdi.....tttttttttttttttttttti.ssss.....ssss......tttttttttttttttttt
dddddedfdcduuuuuudddddddddddqqqdrrdi.........................i.ssss.....ssss........................
dddddddddfdcduuuuuuuuuuuddddqqqdrrdi.........................i.ssss.....ssss........................
dddedkdllllllldhdddddddddddddddddddivwwwwwwwwwwwwwwwwwwwwwwwwixyyyyvvvvvyyyyyywwwwwwwwwwwwwwwwwwwwww
dddddddfdzdppppppppddddddddddqqdrrdi.AAAA.BBBBBBB.AAAAAA.....i.ssss.....ssss..AAAA.BBBBBBB.AAAAAA...
dedfdgggggggggggggggggdhhhhhhddddddivvvvvBBvvvvCCCCCCvvvvvvvvixyyyyvvvvvyyyyyyvvvvBBvvvvCCCCCCDDDDDD
dddddfdEdFFFFFFFFddddddddddddddddddi.....BBBBB...CCC.........i.ssss.....ssss......BBBBB...CCC.......
dddddddddddddddddddddddddddddddddddi.....BBB...BBBB..........i.ssss.....ssss......BBB...BBBB........
dddddddddddddddddddddddddddddddddddi.........................i.ssss.....ssss........................
dddddddddddddddddddddddddddddddddddi.........................i.ssss.....ssss........................
dddddddddddddddddddddddddddddddddddi.wwwwwwwwwwwwwwwwwwwwwwwwi.ssss.....ssss..wwwwwwwwwwwwwwwwwwwwww
dddddddddddddddddddddddddddddddddddi.AAAA....BBBBBBB..GGGGG..i.ssss.....ssss..AAAA....BBBBBBB..GGGGG
dddddddddddddddddddddddddddddddddddivvvvvvvvvvvDDDDvvvvvvvvvvixyyyyvvvvvyyyyyyvvvvDDDvvvvvvvDDDvvvvv
dddddddddddddddddddddddddddddddddddi.....AAA.............AAAAi.ssss.....ssss......AAA.............AA
dddddddddddddddddddddddddddddddddddi.........................i.ssss.....ssss........................
dddddddddddddddddddddddddddddddddddi.........................i.ssss.....ssss........................
dddddddddddddddddddddddddddddddddddiHHHHHHHHHHHHHHHHHHHHHHHHHiIHHHHJJJJJKKKKKKJJJJAAJJJBBBJJJJAAAJJJ
dddddddddddddddddddddddddddddddddddiHHHHHHHHHHHHHHHHHHHHHHHHHi.HHHHJJJJJKKKKKKJJJJJJJJAAAAAAJJJJJJJJ
dddddddddddddddddddddddddddddddddddiHHHHHHHHHHHHHHHHHHHHHHHHHi.HHHHJJJJJKKKKKKJJJJJJJJJJJJJJJJJJJJJJ
dddddddddddddddddddddddddddddddddddi.....AAAAAA...BBB.GGGGG..i.ssss.....ssss......AAAAAA...BBB.GGGGG
dddddddddddddddddddddddddddddddddddi.........................i.ssss.....ssss........................
dddddddddddddddddddddddddddddddddddi.........................i.ssss.....ssss........................
dddddddddddddddddddddddddddddddddddi.wwwwwwwwwwwwwwwwwwwwwwwwi.ssss.....ssss..wwwwwwwwwwwwwwwwwwwwww
dddddddddddddddddddddddddddddddddddi.AAAA....BBBBBBB..GGG...Ci.ssss.....ssss..AAAA....BBBBBBB..GGG..
dddddddddddddddddddddddddddddddddddi.....AAAAAA.....GGGGGGG.ti.ssss.....ssss......AAAAAA.....GGGGGGG
LLLLLLLLMMMMMMMMNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNOOOOOOOOOOOOOON
```

Legend: `a` [BufferLineFill] · `b` [BufferLineBufferSelected] · `c` [DevIconGo] · `d` [FileTreeNormal] · `e` [FileTreeExpander] · `f` [ChangesCheckbox] · `g` [ChangesRoot] · `h` [ChangesCount] · `i` [WinSeparator] · `j` [DiffViewHeader] · `k` [FileTreeFolderIcon] · `l` [FileTreeFolderName] · `m` [DiffViewFold] · `n` [DiffViewFoldText] · `o` [FileTreeCursorLine] · `p` [FileTreeGitModified] · `q` [ChangesStatAdded] · `r` [ChangesStatRemoved] · `s` [DiffViewLineNr] · `t` [@string] · `u` [FileTreeGitAdded] · `v` [DiffViewChange] · `w` [@comment] · `x` [DiffViewArrowChange] · `y` [DiffViewGutterChange] · `z` [DevIconTs] · `A` [@keyword] · `B` [@type] · `C` [@type.builtin] · `D` [DiffViewWord] · `E` [DevIconMd] · `F` [FileTreeGitUntracked] · `G` [@function] · `H` [DiffViewPadding] · `I` [DiffViewArrowAdd] · `J` [DiffViewAdd] · `K` [DiffViewGutterAdd] · `L` [lualine_a_normal] · `M` [lualine_b_normal] · `N` [lualine_c_normal] · `O` [StatuslineLangText] · `.` [Normal]

The diff side is `diff-view`'s layout (its Decisions 3–5, approved `diff2_aligned`) in the 64 columns right of the panel: the left window takes 40% (25 columns, a 1-cell status column and 24 of code), a blank separator, then the right window's 16-cell gutter (`»`, left number, 5-cell strip, right number, checkbox) and 22 columns of code. Lines 1–4 fold (context 4 before line 9); changed lines 9, 11 and 18 carry word highlights where they fit; the 3-line insert after line 21 is padded on the left; the 6-line insert at the end is below the screen. The screen scenario covers rows 2-29.

## Risks / Trade-offs

- **Coupling to `diff-view`.** The panel relies on its "Diff view embedding" requirement (`show(win, spec)` without focus, replace on a second `show`, `on_next_file`). If that API changes before this change drains, the implementation follows it; the scenarios name only windows, lines and focus.
- **Big repositories.** `git status --untracked-files=all` on a repo with many untracked files is slow; refresh is async, coalesced and generation-checked, so typing never waits. A `.gitignore`d `node_modules` is not listed.
- **Refresh triggers miss external changes** made while Neovim keeps focus (a script in another zellij pane without `FocusGained`). `<A-G>` twice or any own git action refreshes; a file watcher is out of scope.
- **Nesting rules are the project tree's.** A user rule that nests unrelated files nests them here too; that is intended (one rule set).
