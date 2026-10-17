## Context

Today `<A-e>` opens neo-tree's `filesystem` source (`lua/gleb/file_tree/init.lua`). The `file-tree` spec pins its window (left, 35 columns, `close_if_last_window`), its glyphs (expanders U+F460/U+F47C, folders U+E5FF/U+E5FE/U+F0256), following the current file, the libuv watcher and the netrw hijack. The `bufferline` spec pins the tab offset for the `neo-tree` filetype.

The user picked IntelliJ's Project view look (`ft_idea`, rendered by the planning generator `tree_gen.py`, `Style()`):
- name colour only, with changed folders tinted;
- compact middle folders, no guides, devicons;
- a bold root row with its path in grey.

Nesting (the chevron on `invoice.go`) belongs to `file-tree-nesting`, and hiding ignored entries to `file-tree-ignored`. So this change renders `ft_idea` with nested files as plain siblings, on a fixture copy without ignored entries.

What the new tree carries over from neo-tree, and when:

| neo-tree behaviour | New tree |
|---|---|
| left, 35 columns, `close_if_last_window` | this change |
| bufferline offset | this change (`gleb-file-tree` entry) |
| follow current file, libuv watcher | this change |
| expander and folder glyphs | this change, same codepoints |
| dotfiles listed | this change; `.git` hidden |
| gitignored entries listed | listed until `file-tree-ignored` hides them by default |
| netrw hijack (`:edit <dir>`) | `tree-diff-cutover`; neo-tree keeps it until then |
| `<A-e>` toggle | `tree-diff-cutover` rebinds it to `file_tree.toggle` |
| add, delete, rename, copy, cut, paste, refresh | `file-tree-ops` |
| `H` toggle hidden | `file-tree-ignored` (`file_tree.show_ignored`) |

## Goals / Non-Goals

**Goals:**
- An IntelliJ-like sidebar tree that we own.
- A pure model that later changes extend: nesting rules and the ignore filter become stages of the row model.
- Live git colours and filesystem updates that never block the editor.
- The approved render, reproducible on a real fixture.

**Non-Goals:**
- File operations, nesting and ignored entries (the next three changes).
- Replacing neo-tree or rebinding keys (`tree-diff-cutover`).
- A float project view, diagnostics markers, multiple roots.

## Decisions

1. **Modules** (`lua/gleb/file_tree/`, rule 1.x):
   - `model.lua` is pure (rule 1.3, no `vim.uv`, no plugin requires):
     - `sort(entries)`;
     - `rows(tree, expanded, status)`: flattens the visible tree into rows `{ depth, kind, label, path, expanded, empty, status }`;
     - `parse_status(porcelain_z, prefix)`;
     - `folder_status(status, path)`.
   - `fs.lua` scans a folder with `vim.uv.fs_scandir`. A symlink to a folder is a folder that the watchers do not follow. A broken symlink is a file.
   - `git.lua` runs status, `watch.lua` owns the `fs_event` handles, and `expanded.lua` handles persistence. Each module has `M.state` and `M.reset()` (rule 1.5).
   - `render.lua` turns rows into lines and extmarks and defines the highlight groups.
   - `view.lua` owns windows, buffers and autocmds (augroups `gleb_file_tree_view`, `gleb_file_tree_highlights`).
   - The neo-tree setup moves verbatim to `neo_tree.lua`. `init.lua` requires `gleb.file_tree.neo_tree`, then calls `require("gleb.file_tree.view").setup()`, so the new tree loads even without neo-tree.
2. **Order:** folders first, then files.
   - The key is `name:lower()`, with the raw name breaking ties. So `Makefile` sorts between `go.mod` and `notes.md`, and `package-lock.json` before `package.json`.
   - No natural-number ordering.
3. **Compact chains** (IntelliJ "compact middle packages"):
   - While a folder's visible entries are exactly one folder, the row takes the child's name as `a/b` and continues down the chain.
   - Chains merge whatever their expansion. That costs one extra scan per chain member, done lazily when the row is built.
   - Expansion is keyed by the relative path of the chain's last folder (`cmd/server`). Splitting a chain keeps every folder's own state.
   - "Visible" means after the later filters (ignore, nesting), so `web` stays a single row once `node_modules` is hidden.
4. **Root row and columns:**
   - The root row is `U+F47C U+E5FE <basename>  <fnamemodify(root, ":~")>`. The path is cut from the left with `…` to fit the window. The name is never cut.
   - The root is always expanded, and `h`, `za` and `zM` never collapse it.
   - Entries at depth `d` start at column `3 + 2d`: the expander there, the icon 2 columns later, the name 4 columns later.
   - Files have no expander, so their icons line up with folder icons.
   - An expanded empty folder shows no expander and U+F0256.
5. **Git status** (`git.lua`):
   - The command is `git --no-optional-locks -C <root> status --porcelain=v2 -z --untracked-files=normal`, run with `vim.system` (rule 6.4).
     - `--no-optional-locks` never takes `index.lock`, so a running `git commit` is never disturbed. VS Code does the same.
     - The toplevel comes from one `git rev-parse --show-toplevel` per root. Porcelain paths are relative to it and are mapped to the root.
   - Records:
     - `1 XY`: `A` in X is added; `D` in X or Y is deleted (no row, but it tints folders); otherwise modified.
     - `2` is renamed (on the new path), `u` is conflict, `?` is untracked.
     - A `?` path ending in `/` marks that folder and everything below it.
   - Throttle:
     - Requests are debounced by `GIT_DEBOUNCE_MS = 150`.
     - At most one run is in flight. Requests during a run set a dirty flag, which causes exactly one follow-up run.
     - Results are applied in `vim.schedule` only while their generation is current and the tree buffer is valid (rule 6.3).
     - `state.runs` and `state.last_cmd` exist for the tests.
   - Outside a repository, or on any failure, the tree has no colours and notifies nothing (rule 8.4: background work is silent).
6. **Folder tint:** a folder takes the strongest status of any path below it, in the order conflict > modified (modified, renamed, deleted) > added > untracked. The root row is never tinted.
7. **Live updates** (`watch.lua`):
   - Non-recursive `fs_event` handles on the root, on every expanded folder (on the chain's last folder for a compact row) and on the git dir (`index`, `HEAD`, refs).
   - Events are debounced per folder by `WATCH_DEBOUNCE_MS = 100`, then the folder is rescanned and redrawn. Worktree and git-dir events request a git status run.
   - Git status also reruns on `BufWritePost` under the root and on `FocusGained`.
   - Handles close when their folder collapses, when the last tree window for the root closes, on re-root and on `VimLeavePre` (rule 6.5).
   - `M.state.handles` maps folder paths to handles, and `M.stop_all()` closes them all. `file-tree-ops` tests use it to show that `R` does not depend on the watchers.
8. **Following:**
   - `BufEnter` of a normal buffer whose real path lies under the root reveals that path in the current tab's tree: expand the ancestors, redraw, move the tree cursor. Focus does not move.
   - `scheme://` buffers and files outside the root are ignored.
   - `file_tree.reveal` does the same after opening and focusing the tree. Without a file on disk the cursor goes to the root row.
   - `file_tree.toggle` reveals the current file when it opens the tree, like today's `tree.toggle_filesystem`.
9. **Window:**
   - Opened with `topleft vertical 35 split`.
   - Window options: `winfixwidth`, `cursorline`, `nonumber`, `norelativenumber`, `signcolumn=no`, `foldcolumn=0`, `nowrap`, `nolist`, `nospell`, `winhighlight=Normal:FileTreeNormal,CursorLine:FileTreeCursorLine`.
   - Buffer: `buftype=nofile`, `bufhidden=wipe`, `noswapfile`, `nomodifiable`, unlisted, named `gleb-file-tree://<root>#<tabnr>`.
   - The cursor is hidden while the tree is focused: `guicursor` gets the blended `FileTreeHiddenCursor` group on `WinEnter` and is restored on `WinLeave`. The cursor line marks the selection.
   - Close-if-last: on `QuitPre`, if the quitting window is the tab's last non-floating, non-tree window, the tab's tree windows close first. `:q` then exits or closes the tab, as without a tree.
10. **Persistence** (`expanded.lua`):
    - `stdpath("state")/file_tree/expanded.json` holds `{ "<root>": ["cmd/server", "internal", …] }`, sorted.
    - Writes are debounced by 500 ms and flushed on tree close and on `VimLeavePre`.
    - Missing folders are dropped when the tree opens.
    - On `DirChanged` with scope `global` the tree re-roots and loads the new root's set.
11. **Actions and keys:**
    - New entries in `file_tree/actions.lua`, category `Project`, so descs read `Project: <title>` (rule 3.3).
    - `file_tree.toggle` ("Toggle Project Tree") and `file_tree.reveal` ("Reveal in Project Tree") have no `ft` and stay unbound until `tree-diff-cutover`.
    - The view actions carry `ft = "gleb-file-tree"`, and their keys go into `settings/keymap.json` (rule 3.1). `zM`/`zR`/`za` shadow the built-in fold commands only in the tree buffer.
    - `find_action/assign.lua` maps the id prefix `file_tree` to the neo-tree adapter, which would wrongly say "applies when neo-tree reopens" for the new actions. That entry is removed.
    - The find-action test fixture that used `file_tree.open` as its adapter example switches to a `neo_tree.` id. Its assertion is unchanged.
12. **Folds:**
    - `file_tree.unfold_all` expands breadth-first and stops at `UNFOLD_ALL_MAX_ROWS = 5000` with the WARN `Unfold all stopped at 5000 rows`. Before `file-tree-ignored`, `node_modules` would otherwise be walked in full.
    - `file_tree.fold_all` clears the expanded set except the root.
13. **Highlights** (`render.lua`, rule 8.7, redefined on `ColorScheme`):

    | Group | Colour |
    |---|---|
    | `FileTreeNormal` | link `Normal` |
    | `FileTreeRoot` | fg1, bold |
    | `FileTreeRootPath`, `FileTreeExpander` | grey1 |
    | `FileTreeFolderIcon` | blue |
    | `FileTreeFolderName`, `FileTreeFileName` | fg0 |
    | `FileTreeGitModified` | blue |
    | `FileTreeGitAdded` | green |
    | `FileTreeGitUntracked` | orange |
    | `FileTreeGitDeleted` | grey1, strikethrough (used by `git-changes-tree`) |
    | `FileTreeGitRenamed` | aqua |
    | `FileTreeGitConflict` | red |
    | `FileTreeCursorLine` | bg1 |
    | `FileTreeHiddenCursor` | blend 100 |

    - Icons come from nvim-web-devicons `get_icon(name, nil, { default = true })` (multi-dot names such as `price.d.ts` resolve), required with `pcall` (rule 2.5). Without it, files get U+F15B in `FileTreeFileName`.
14. **Coexistence:**
    - neo-tree, its keys and its scenarios are untouched.
    - Both trees may be open at once. Each filetype has its own bufferline offset entry.
    - The directory hijack stays with neo-tree until `tree-diff-cutover`, which also moves it to the new tree.

## Fixture

`tests/fixtures/build.sh` gains `treeproj` (and its line in the header comment and the `case` list). It is the planning generator's sample repo as a real git repo. The exact function:

```sh
treeproj() {
	git init -q
	mkdir -p .github/workflows cmd/server internal/billing internal/money web/src
	printf 'bin/\nnode_modules/\n.env\n' >.gitignore
	printf 'module example.com/billing\n\ngo 1.22\n' >go.mod
	: >go.sum
	printf 'test:\n\tgo test ./...\n' >Makefile
	printf '# billing\n\nInvoices, tax and money formatting.\n' >README.md
	cat >.github/workflows/ci.yml <<'EOF'
name: ci
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: go test ./...
EOF
	cat >cmd/server/main.go <<'EOF'
package main

import (
	"fmt"

	"example.com/billing/internal/billing"
)

func main() {
	inv := billing.Invoice{ID: "INV-1", Lines: []int{100, 250}}
	fmt.Println(inv.Due())
}
EOF
	cat >internal/billing/discount.go <<'EOF'
package billing

// Discount takes percent off an amount in cents.
func Discount(cents, percent int) int {
	return cents - cents*percent/100
}
EOF
	cat >internal/billing/discount_test.go <<'EOF'
package billing

import "testing"

func TestDiscount(t *testing.T) {
	if got := Discount(200, 10); got != 180 {
		t.Fatalf("Discount = %d", got)
	}
}
EOF
	cat >internal/billing/invoice.go <<'EOF'
package billing

import (
	"fmt"

	"example.com/billing/internal/money"
)

// Invoice is a list of line amounts in cents.
type Invoice struct {
	ID    string
	Lines []int
}

// Total sums the lines and applies the tax rate.
func (i Invoice) Total() int {
	total := 0
	for _, cents := range i.Lines {
		total += cents
	}
	return total
}

// Due renders the total as dollars.
func (i Invoice) Due() string {
	return fmt.Sprintf("due %s", money.Format(i.Total()))
}
EOF
	cat >internal/billing/invoice_test.go <<'EOF'
package billing

import "testing"

func TestDue(t *testing.T) {
	inv := Invoice{Lines: []int{100, 250}}
	if got := inv.Due(); got != "due $3.50" {
		t.Fatalf("Due = %q", got)
	}
}
EOF
	cat >internal/money/money.go <<'EOF'
package money

import "fmt"

// Format renders cents as dollars.
func Format(cents int) string {
	return fmt.Sprintf("$%d.%02d", cents/100, cents%100)
}
EOF
	cat >internal/money/money_test.go <<'EOF'
package money

import "testing"

func TestFormat(t *testing.T) {
	if got := Format(350); got != "$3.50" {
		t.Fatalf("Format = %q", got)
	}
}
EOF
	printf '{\n  "name": "billing-web",\n  "private": true\n}\n' >web/package.json
	printf '{\n  "name": "billing-web",\n  "lockfileVersion": 3,\n  "requires": true,\n  "packages": {}\n}\n' \
		>web/package-lock.json
	cat >web/src/cart.tsx <<'EOF'
import { price } from "./price";

export function Cart({ cents }: { cents: number }) {
  return <span>{price(cents)}</span>;
}
EOF
	printf 'export function price(cents: number): string {\n  return `$${cents / 100}`;\n}\n' >web/src/price.ts
	printf 'export declare function price(cents: number): string;\n' >web/src/price.d.ts
	cat >web/src/price.test.ts <<'EOF'
import { price } from "./price";

test("price", () => {
  expect(price(350)).toBe("$3.5");
});
EOF
	commit "billing service"
	# modified (unstaged): invoice.go gains the Tax field, invoice_test.go and price.ts change
	cat >internal/billing/invoice.go <<'EOF'
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
EOF
	cat >internal/billing/invoice_test.go <<'EOF'
package billing

import "testing"

func TestDue(t *testing.T) {
	inv := Invoice{Lines: []int{100, 250}, Tax: 10}
	if got := inv.Due(); got != "due $3.85" {
		t.Fatalf("Due = %q", got)
	}
}
EOF
	printf 'export function price(cents: number): string {\n  return `$${(cents / 100).toFixed(2)}`;\n}\n' >web/src/price.ts
	# added (staged)
	cat >internal/billing/tax.go <<'EOF'
package billing

// Rate is a tax rate in percent.
type Rate int

// Apply adds the tax to an amount in cents.
func (r Rate) Apply(cents int) int {
	return cents + cents*int(r)/100
}
EOF
	cat >internal/billing/tax_test.go <<'EOF'
package billing

import "testing"

func TestApply(t *testing.T) {
	if got := Rate(10).Apply(200); got != 220 {
		t.Fatalf("Apply = %d", got)
	}
}
EOF
	git add internal/billing/tax.go internal/billing/tax_test.go
	# untracked
	printf '# notes\n\n- tax rounding\n' >notes.md
	# ignored (.gitignore)
	mkdir -p bin web/node_modules/left-pad
	printf '#!/bin/sh\necho server\n' >bin/server
	printf 'module.exports = (s) => s;\n' >web/node_modules/left-pad/index.js
	printf 'TAX_RATE=10\n' >.env
	printf '{"modified":["internal/billing/invoice.go","internal/billing/invoice_test.go","web/src/price.ts"],"added":["internal/billing/tax.go","internal/billing/tax_test.go"],"untracked":["notes.md"],"ignored":["bin/","web/node_modules/",".env"]}\n' \
		>../manifest.json
}
```

Resulting state (`git status --porcelain=v2`): `.M` `internal/billing/invoice.go`, `internal/billing/invoice_test.go` and `web/src/price.ts`; `A.` `internal/billing/tax.go` and `tax_test.go`; `?` `notes.md`; ignored (`!`) `bin/`, `web/node_modules/` and `.env`.

Tests use `F.copy("treeproj", dir .. "/work/billing")`. The screen test sets the child's `HOME` to `dir`, so the root path reads `~/work/billing`, and deletes the three ignored entries from its copy.

## Renders

Stand-ins: `▸ ▾` expanders, `■ □` closed/open folder, `◆` devicons and other Nerd Font glyphs, `✗ ▲` diagnostics, `( )` chip caps, `⎇` branch. The real-glyph, real-colour renders are `renders/f1_current.ansi` and `renders/f1_proposed.ansi`; view them with `command cat`.

Both renders come from a real capture: neo-tree on the fixture, made by a scratch render case in the real config. The Proposed one keeps the real tabline, editor and statusline. Its tree window is drawn by the planning generator from this design's model rules, run on the real fixture and its real `git status`. The masks cover the tree window and the separator column. The editor, tabline and statusline cells are `.`, because this change does not alter them. Check with `make colorize FILE=openspec/changes/file-tree-view/design.md CASE=neo-tree` (the neo-tree case primes the `NeoTree*` groups): only the new `FileTree*` groups are unknown until this change defines them.

**Current F1 — neo-tree**: `100x30`, Normal, neo-tree `filesystem` focused, cursor on `invoice.go`; a copy of the `treeproj` fixture with its ignored entries at `~/work/billing`; `cmd/server`, `internal/billing` and `web/src` revealed; `internal/billing/invoice.go` in the editor; no LSP. Real capture; the root path is shortened to `~`.

```text
                                          ◆ invoice.go                                              
 □ ~/work/billing                  ┃  1   package billing                                           
 ▸ ■ .git                          ┃    1                                                           
 ▸ ■ .github                       ┃    2 import (                                                  
 ▸ ■ bin                         ◌ ┃    3 ▏ "fmt"                                                   
 ▾ □ cmd                           ┃    4 ▏                                                         
   ▾ □ server                      ┃    5 ▏ "example.com/billing/internal/money"                    
     └ ◆ main.go                   ┃    6 )                                                         
 ▾ □ internal                      ┃    7                                                           
   ▾ □ billing                     ┃    8 // Invoice is a list of line amounts in cents.            
   │ │ ◆ discount.go               ┃    9 type Invoice struct {                                     
   │ │ ◆ discount_test.go          ┃   10 ▏ ID    string                                            
   │ │ ◆ invoice.go            ◆   ┃   11 ▏ Lines []int                                             
   │ │ ◆ invoice_test.go       ◆   ┃┃  12 ▏ Tax   Rate                                              
   │ │ ◆ tax.go                ✚ » ┃   13 }                                                         
   │ └ ◆ tax_test.go           ✚ » ┃   14                                                           
   ▸ ■ money                       ┃   15 // Total sums the lines and applies the tax rate.         
 ▾ □ web                           ┃   16 func (i Invoice) Total() int {                            
   ▸ ■ node_modules              ◌ ┃   17 ▏ total := 0                                              
   ▾ □ src                         ┃   18 ▏ for _, cents := range i.Lines {                         
   │ │ ◆ cart.tsx                  ┃   19 ▏ ▏ total += cents                                        
   │ │ ◆ price.d.ts                ┃   20 ▏ }                                                       
   │ │ ◆ price.test.ts             ┃┃  21 ▏ return i.Tax.Apply(total)                               
   │ └ ◆ price.ts              ◆   ┃   22 }                                                         
   │ ◆ package-lock.json           ┃   23                                                           
   └ ◆ package.json                ┃   24 // Due renders the total as dollars.                      
   ◆ .env                        ◌ ┃   25 func (i Invoice) Due() string {                           
   ◆ .gitignore                    ┃   26 ▏ return fmt.Sprintf("due %s", money.Format(i.Total()))   
   ◆ Makefile                      ┃   27 }                                                         
 NORMAL  ⎇ main                                                               ✗ 0 ▲ 0 ( ◆ neo-tree )
```

```text
....................................................................................................
abbccccccccccccccccccccccccccccccccd................................................................
eeebbffffaaaaaaaaaaaaaaaaaaaaaaaaaad................................................................
eeebbfffffffaaaaaaaaaaaaaaaaaaaaaaad................................................................
eeebbgggaaaaaaaaaaaaaaaaaaaaaaaaaggd................................................................
eeebbfffaaaaaaaaaaaaaaaaaaaaaaaaaaad................................................................
aaaeebbffffffaaaaaaaaaaaaaaaaaaaaaad................................................................
aaaaahhiijjjjjjjaaaaaaaaaaaaaaaaaaad................................................................
eeebbkkkkkkkkaaaaaaaaaaaaaaaaaaaaaad................................................................
aaaeebbkkkkkkkaaaaaaaaaaaaaaaaaaaaad................................................................
aaahhhhiijjjjjjjjjjjaaaaaaaaaaaaaaad................................................................
aaahhhhiijjjjjjjjjjjjjjjjaaaaaaaaaad................................................................
lllhlhlilkkkkkkkkkkllllllllllllkllld................................................................
aaahhhhiikkkkkkkkkkkkkkkaaaaaaakkmmd................................................................
aaahhhhiinnnnnnaaaaaaaaaaaaaaaannood................................................................
aaahhhhiinnnnnnnnnnnaaaaaaaaaaannood................................................................
aaaeebbfffffaaaaaaaaaaaaaaaaaaaaaaad................................................................
eeebbkkkaaaaaaaaaaaaaaaaaaaaaaaaaaad................................................................
aaaeebbggggggggggggaaaaaaaaaaaaaaggd................................................................
aaaeebbkkkaaaaaaaaaaaaaaaaaaaaaaaaad................................................................
aaahhhhppjjjjjjjjaaaaaaaaaaaaaaaaaad................................................................
aaahhhhqqjjjjjjjjjjaaaaaaaaaaaaaaaad................................................................
aaahhhhrrjjjjjjjjjjjjjaaaaaaaaaaaaad................................................................
aaahhhhsskkkkkkkkaaaaaaaaaaaaaakkmmd................................................................
aaahhttjjjjjjjjjjjjjjjjjaaaaaaaaaaad................................................................
aaahhuujjjjjjjjjjjjaaaaaaaaaaaaaaaad................................................................
aaavvggggaaaaaaaaaaaaaaaaaaaaaaaaggd................................................................
aaawwjjjjjjjjjjaaaaaaaaaaaaaaaaaaaad................................................................
aaaxxjjjjjjjjaaaaaaaaaaaaaaaaaaaaaad................................................................
....................................................................................................
```

Legend: `a` [NeoTreeNormal] · `b` [NeoTreeDirectoryIcon] · `c` [NeoTreeRootName] · `d` [WinSeparator] · `e` [NeoTreeExpander] · `f` [NeoTreeDirectoryName] · `g` [NeoTreeGitIgnored] · `h` [NeoTreeIndentMarker] · `i` [DevIconGo] · `j` [NeoTreeFileName] · `k` [NeoTreeGitModified] · `l` [NeoTreeCursorLine] · `m` [NeoTreeGitUnstaged] · `n` [NeoTreeGitAdded] · `o` [NeoTreeGitStaged] · `p` [DevIconTsx] · `q` [DevIconTypeScriptDeclaration] · `r` [DevIconTestTs] · `s` [DevIconTypeScript] · `t` [DevIconPackageLockJson] · `u` [DevIconPackageJson] · `v` [DevIconEnv] · `w` [DevIconGitIgnore] · `x` [DevIconMakefile] · `.` [Normal]

**Proposed F1 — project tree** (approved: `ft_idea` without nesting): `100x30`, Normal, project tree focused, cursor on `invoice.go`; a copy of the `treeproj` fixture without its ignored entries at `~/work/billing`; `cmd/server`, `internal`, `internal/billing`, `web` and `web/src` expanded; `internal/billing/invoice.go` in the editor; no LSP.

```text
                                          ◆ invoice.go                                              
 ▾ □ billing  ~/work/billing       ┃  1   package billing                                           
   ▸ ■ .github/workflows           ┃    1                                                           
   ▾ □ cmd/server                  ┃    2 import (                                                  
       ◆ main.go                   ┃    3 ▏ "fmt"                                                   
   ▾ □ internal                    ┃    4 ▏                                                         
     ▾ □ billing                   ┃    5 ▏ "example.com/billing/internal/money"                    
         ◆ discount.go             ┃    6 )                                                         
         ◆ discount_test.go        ┃    7                                                           
         ◆ invoice.go              ┃    8 // Invoice is a list of line amounts in cents.            
         ◆ invoice_test.go         ┃    9 type Invoice struct {                                     
         ◆ tax.go                  ┃   10 ▏ ID    string                                            
         ◆ tax_test.go             ┃   11 ▏ Lines []int                                             
     ▸ ■ money                     ┃┃  12 ▏ Tax   Rate                                              
   ▾ □ web                         ┃   13 }                                                         
     ▾ □ src                       ┃   14                                                           
         ◆ cart.tsx                ┃   15 // Total sums the lines and applies the tax rate.         
         ◆ price.d.ts              ┃   16 func (i Invoice) Total() int {                            
         ◆ price.test.ts           ┃   17 ▏ total := 0                                              
         ◆ price.ts                ┃   18 ▏ for _, cents := range i.Lines {                         
       ◆ package-lock.json         ┃   19 ▏ ▏ total += cents                                        
       ◆ package.json              ┃   20 ▏ }                                                       
     ◆ .gitignore                  ┃┃  21 ▏ return i.Tax.Apply(total)                               
     ◆ go.mod                      ┃   22 }                                                         
     ◆ go.sum                      ┃   23                                                           
     ◆ Makefile                    ┃   24 // Due renders the total as dollars.                      
     ◆ notes.md                    ┃   25 func (i Invoice) Due() string {                           
     ◆ README.md                   ┃   26 ▏ return fmt.Sprintf("due %s", money.Format(i.Total()))   
                                   ┃   27 }                                                         
 NORMAL  ⎇ main                                                         ✗ 0 ▲ 0 ( ◆ gleb-file-tree )
```

```text
....................................................................................................
abacadddddddaaeeeeeeeeeeeeeeaaaaaaaf................................................................
aaabacagggggggggggggggggaaaaaaaaaaaf................................................................
aaabacaggggggggggaaaaaaaaaaaaaaaaaaf................................................................
aaaaaaahaiiiiiiiaaaaaaaaaaaaaaaaaaaf................................................................
aaabacajjjjjjjjaaaaaaaaaaaaaaaaaaaaf................................................................
aaaaabacajjjjjjjaaaaaaaaaaaaaaaaaaaf................................................................
aaaaaaaaahaiiiiiiiiiiiaaaaaaaaaaaaaf................................................................
aaaaaaaaahaiiiiiiiiiiiiiiiiaaaaaaaaf................................................................
kkkkkkkkkhkjjjjjjjjjjkkkkkkkkkkkkkkf................................................................
aaaaaaaaahajjjjjjjjjjjjjjjaaaaaaaaaf................................................................
aaaaaaaaahallllllaaaaaaaaaaaaaaaaaaf................................................................
aaaaaaaaahalllllllllllaaaaaaaaaaaaaf................................................................
aaaaabacagggggaaaaaaaaaaaaaaaaaaaaaf................................................................
aaabacajjjaaaaaaaaaaaaaaaaaaaaaaaaaf................................................................
aaaaabacajjjaaaaaaaaaaaaaaaaaaaaaaaf................................................................
aaaaaaaaamaiiiiiiiiaaaaaaaaaaaaaaaaf................................................................
aaaaaaaaanaiiiiiiiiiiaaaaaaaaaaaaaaf................................................................
aaaaaaaaaoaiiiiiiiiiiiiiaaaaaaaaaaaf................................................................
aaaaaaaaapajjjjjjjjaaaaaaaaaaaaaaaaf................................................................
aaaaaaaqaiiiiiiiiiiiiiiiiiaaaaaaaaaf................................................................
aaaaaaaraiiiiiiiiiiiiaaaaaaaaaaaaaaf................................................................
aaaaasaiiiiiiiiiiaaaaaaaaaaaaaaaaaaf................................................................
aaaaataiiiiiiaaaaaaaaaaaaaaaaaaaaaaf................................................................
aaaaauaiiiiiiaaaaaaaaaaaaaaaaaaaaaaf................................................................
aaaaavaiiiiiiiiaaaaaaaaaaaaaaaaaaaaf................................................................
aaaaawaxxxxxxxxaaaaaaaaaaaaaaaaaaaaf................................................................
aaaaayaiiiiiiiiiaaaaaaaaaaaaaaaaaaaf................................................................
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaf................................................................
....................................................................................................
```

Legend: `a` [FileTreeNormal] · `b` [FileTreeExpander] · `c` [FileTreeFolderIcon] · `d` [FileTreeRoot] · `e` [FileTreeRootPath] · `f` [WinSeparator] · `g` [FileTreeFolderName] · `h` [DevIconGo] · `i` [FileTreeFileName] · `j` [FileTreeGitModified] · `k` [FileTreeCursorLine] · `l` [FileTreeGitAdded] · `m` [DevIconTsx] · `n` [DevIconTypeScriptDeclaration] · `o` [DevIconTestTs] · `p` [DevIconTypeScript] · `q` [DevIconPackageLockJson] · `r` [DevIconPackageJson] · `s` [DevIconGitIgnore] · `t` [DevIconGoMod] · `u` [DevIconGoSum] · `v` [DevIconMakefile] · `w` [DevIconMd] · `x` [FileTreeGitUntracked] · `y` [DevIconReadme] · `.` [Normal]

Differences from the approved `ft_idea` mock-up:
- Nested files (`discount_test.go`, `go.sum`, `package-lock.json`, `price.d.ts`, `price.test.ts`) are plain sibling rows until `file-tree-nesting`.
- The chrome is the real config's (bufferline tab, relative numbers, gitsigns bars, the language chip `gleb-file-tree`) instead of the mock's.
- The fixture's branch is `main`.

## Risks / Trade-offs

- **Large folders.** A scan is one `fs_scandir` per expanded folder, and rows are rebuilt per change. Until `file-tree-ignored` hides `node_modules`, expanding it is slow. The unfold-all cap bounds the worst case.
- **fs_event on macOS** reports coalesced events, sometimes for the parent. Rescanning the whole folder after the debounce makes the exact event kind irrelevant.
- **Two trees during the transition** cost some duplicate watchers when both are open. Accepted until `tree-diff-cutover`.
- **Statusline chip** reads `gleb-file-tree`, which is long. It is the generic filetype chip; a dedicated label would be a statusline change of its own.
