## ADDED Requirements

### Requirement: File tree nesting settings
`settings/file_tree.json` SHALL hold `nesting.enabled` and the ordered list `nesting.rules`. A pattern rule's `parent` and `children` SHALL be Lua patterns matched against a whole file name. A child template's `${capture}` (first capture) and `${1}`…`${9}` SHALL insert the parent's captures literally. A rule with a malformed pattern or an unknown capture SHALL be skipped with a WARN. An unreadable file SHALL disable nesting with an ERROR, and a write from Neovim SHALL reload it.

#### Scenario: Nesting rule nests by capture
- **WHEN** `require("gleb.file_tree.nesting").nest(dir, entries, rules)` gets the files `discount.go`, `discount_test.go`, `invoice.go`, `invoice_test.go`, `invoice_mock.go`, `tax.go` and the one rule `{ parent = "(.+)%.go", children = { "${capture}_test%.go", "${capture}_mock%.go" } }`
- **THEN** it returns exactly `{ ["discount.go"] = { "discount_test.go" }, ["invoice.go"] = { "invoice_mock.go", "invoice_test.go" } }`

#### Scenario: Nesting patterns match whole names
- **WHEN** `nest` gets the files `go.mod`, `go.sum`, `go.sum.bak`, `xgo.mod` and the rule `{ parent = "go%.mod", children = { "go%.sum" } }`
- **THEN** it returns exactly `{ ["go.mod"] = { "go.sum" } }`

#### Scenario: Nesting captures are inserted literally
- **WHEN** `nest` gets the files `a.b.ts`, `a.b.test.ts`, `aXb.test.ts` and the rule `{ parent = "(.+)%.ts", children = { "${capture}%.test%.ts" } }`
- **THEN** it returns exactly `{ ["a.b.ts"] = { "a.b.test.ts" } }`

#### Scenario: Broken nesting rules are skipped
- **WHEN** `nest` gets the files `go.mod`, `go.sum`, `init.lua`, `init_spec.lua` and the rules `{ parent = "go%.mod", children = { "${capture}%.sum" } }`, `{ parent = "[", children = { "x" } }`, `{ parent = "(.+)%.lua", children = { "${capture}_spec%.lua" } }`
- **THEN** it returns exactly `{ ["init.lua"] = { "init_spec.lua" } }`, and WARN notifications starting `File tree nesting rule 1 skipped` and `File tree nesting rule 2 skipped` are shown, once each per load

#### Scenario: Invalid settings file disables nesting
- **WHEN** the settings path holds `{ "nesting": ` and the tree opens on the `treeproj` fixture with `internal/billing` expanded
- **THEN** an ERROR notification starting `File tree settings invalid` is shown, and `discount.go`, `discount_test.go`, `invoice.go`, `invoice_test.go`, `tax.go`, `tax_test.go` are sibling rows without a file chevron

#### Scenario: Writing the settings file reloads nesting
- **WHEN** the tree is open on the `treeproj` fixture with `internal/billing` expanded, the settings path (a temporary copy of the default file) is edited in a buffer to remove the `(.+)%.go` rule, and `:write` is run
- **THEN** within 1 s `invoice_test.go` is a sibling row of `invoice.go`, and `invoice.go` has no chevron

#### Scenario: Nesting can be turned off
- **WHEN** the settings file sets `nesting.enabled` to `false` and the tree opens on the `treeproj` fixture with `internal/billing` expanded
- **THEN** the six Go files of `internal/billing` are sibling rows in name order, and no file row has a chevron

#### Scenario: Writing settings through a normalized path reloads nesting
- **WHEN** `settings.setup` receives a settings path under `/var`, the same file is edited through its normalized `/private/var` path to remove the `(.+)%.go` rule, and `:write` is run
- **THEN** within 1 s `invoice_test.go` is a sibling row of `invoice.go`, and `invoice.go` has no chevron

### Requirement: File tree programmable nesting rules
A rule `{ "lua": "<module>" }` SHALL call the function `require("<module>")` returns with the folder's absolute path and its file names. The returned parent → children map SHALL take part in precedence at the rule's position. Names that are not files of the folder SHALL be ignored. A module that fails to load, errors or returns no table SHALL be skipped with a WARN, and later rules SHALL still apply.

#### Scenario: Lua nesting rule nests by function
- **WHEN** `package.preload["nest_sql"]` returns a function that returns `{ ["schema.sql"] = { "schema_seed.sql", "missing.sql", "schema.sql" } }`, and `nest("/repo/db", entries, { { lua = "nest_sql" } })` gets the files `schema.sql`, `schema_seed.sql`, `other.sql`
- **THEN** the function is called with `"/repo/db"` and the three names, and `nest` returns exactly `{ ["schema.sql"] = { "schema_seed.sql" } }`

#### Scenario: Failing Lua nesting rule is skipped
- **WHEN** `package.preload["nest_boom"]` returns a function that raises `boom`, and `nest` gets the files `init.lua`, `init_spec.lua` and the rules `{ lua = "nest_boom" }`, `{ parent = "(.+)%.lua", children = { "${capture}_spec%.lua" } }`
- **THEN** it returns exactly `{ ["init.lua"] = { "init_spec.lua" } }`, and one WARN notification starting `File tree nesting rule 1 skipped` and containing `boom` is shown

### Requirement: File tree nesting precedence
Nesting SHALL be one level within one folder and SHALL apply to files only. Claims SHALL be taken in rule order, so the first rule that claims a file is its parent. A claim whose parent descends from the child SHALL be dropped. A child whose parent is itself nested SHALL be listed under the top parent. A file SHALL never be its own child. Children SHALL be listed in the tree's name order.

#### Scenario: Earlier nesting rule wins a shared child
- **WHEN** `nest` gets the files `price.ts`, `price.js`, `price.d.ts`, `price.js.map` and the default TypeScript rule followed by the default JavaScript rule
- **THEN** it returns exactly `{ ["price.ts"] = { "price.d.ts", "price.js", "price.js.map" } }`

#### Scenario: Nesting cycles keep rule order
- **WHEN** `nest` gets the files `a.ts`, `a.js` and the rules `{ parent = "(.+)%.ts", children = { "${capture}%.js" } }`, `{ parent = "(.+)%.js", children = { "${capture}%.ts" } }`
- **THEN** it returns exactly `{ ["a.ts"] = { "a.js" } }`

#### Scenario: Folders never nest
- **WHEN** `nest` gets the entries `{ name = "invoice.go", path = "/repo/invoice.go", kind = "file" }`, `{ name = "invoice_test.go", path = "/repo/invoice_test.go", kind = "directory" }` and the default Go rule
- **THEN** it returns an empty table

### Requirement: File tree nesting cache and limits
Nest maps SHALL be cached by the folder's `fs.scan` table and the settings generation, held through weak keys. Reloading settings SHALL bump the generation. Git-only redraws SHALL not run rules again. A substituted child SHALL use a name lookup. The 16 default rules over 5000 files SHALL finish within 50 ms. The 5000-row expansion cap SHALL count nest children.

#### Scenario: Default nesting rules meet the large-folder bound
- **WHEN** `nest` runs all 16 default rules over 5000 file entries after one warm-up run
- **THEN** the measured run finishes within 50 ms

#### Scenario: Git redraw reuses the nest map
- **WHEN** a Lua nesting rule increments a counter, the tree draws one folder, and a git-status update redraws the same unchanged `fs.scan` table without a settings reload
- **THEN** the counter remains `1`

#### Scenario: Unfold all counts nested children toward the row limit
- **WHEN** the root has enough parent files and nested children to exceed 5000 visible rows and `zR` is pressed in normal mode
- **THEN** the tree has at most 5001 rows and a WARN notification `Unfold all stopped at 5000 rows` is emitted

### Requirement: File tree default nesting rules
`settings/file_tree.json` SHALL ship `nesting.enabled = true` and the default rules for Go, protobuf, `go.mod`, `go.work`, TypeScript, TSX, JavaScript, `package.json`, `tsconfig.json`, Python, `pyproject.toml`, `Cargo.toml`, Lua specs, `.gitignore`, `README*` and `Makefile`, in that order, with the children the user approved (design.md Decision 5).

#### Scenario: Default nesting rules nest Go files
- **WHEN** `nest` gets the default rules and the files `invoice.go`, `invoice_test.go`, `invoice_mock.go`, `invoice_string.go`, `api.proto`, `api.pb.go`, `api_grpc.pb.go`, `go.mod`, `go.sum`, `go.work`, `go.work.sum`
- **THEN** it returns exactly `invoice.go` → `invoice_mock.go`, `invoice_string.go`, `invoice_test.go`; `api.proto` → `api.pb.go`, `api_grpc.pb.go`; `go.mod` → `go.sum`; `go.work` → `go.work.sum`

#### Scenario: Default nesting rules nest web files
- **WHEN** `nest` gets the default rules and the files `price.ts`, `price.test.ts`, `price.spec.ts`, `price.d.ts`, `price.js`, `price.d.ts.map`, `price.js.map`, `cart.tsx`, `cart.test.tsx`, `cart.stories.tsx`, `cart.module.css`, `util.js`, `util.min.js`, `util.d.ts`, `package.json`, `package-lock.json`, `yarn.lock`, `.npmrc`, `.nvmrc`, `tsconfig.json`, `tsconfig.build.json`
- **THEN** it returns exactly `price.ts` → `price.d.ts`, `price.d.ts.map`, `price.js`, `price.js.map`, `price.spec.ts`, `price.test.ts`; `cart.tsx` → `cart.module.css`, `cart.stories.tsx`, `cart.test.tsx`; `util.js` → `util.d.ts`, `util.min.js`; `package.json` → `.npmrc`, `.nvmrc`, `package-lock.json`, `yarn.lock`; `tsconfig.json` → `tsconfig.build.json`

#### Scenario: Default nesting rules nest Python and Rust files
- **WHEN** `nest` gets the default rules and the files `money.py`, `money.pyi`, `test_money.py`, `money_test.py`, `pyproject.toml`, `uv.lock`, `requirements-dev.txt`, `setup.cfg`, `setup.py`, `.python-version`, `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`, `rustfmt.toml`, `.rustfmt.toml`, `clippy.toml`
- **THEN** it returns exactly `money.py` → `money.pyi`, `money_test.py`, `test_money.py`; `pyproject.toml` → `.python-version`, `requirements-dev.txt`, `setup.cfg`, `setup.py`, `uv.lock`; `Cargo.toml` → `.rustfmt.toml`, `Cargo.lock`, `clippy.toml`, `rust-toolchain.toml`, `rustfmt.toml`

#### Scenario: Default nesting rules nest project files
- **WHEN** `nest` gets the default rules and the files `init.lua`, `init_spec.lua`, `.gitignore`, `.gitattributes`, `.gitmodules`, `README.md`, `CHANGELOG.md`, `LICENSE`, `Makefile`, `rules.mk`
- **THEN** it returns exactly `init.lua` → `init_spec.lua`; `.gitignore` → `.gitattributes`, `.gitmodules`; `README.md` → `CHANGELOG.md`, `LICENSE`; `Makefile` → `rules.mk`

### Requirement: File tree nest rows
A file with at least one present child SHALL show a chevron in the expander column, drawn with `FileTreeExpander` in the folder expander glyphs, collapsed or expanded. Every nest SHALL start collapsed. Child rows SHALL follow their parent, indented one level deeper, with no chevron and the same icon and name groups as other files. A nest's expanded state SHALL survive refreshes for as long as the tree lives.

#### Scenario: Nests start collapsed under a chevron
- **WHEN** `file_tree.toggle` opens the tree on the `treeproj` fixture and `internal/billing` is expanded
- **THEN** that folder's rows are exactly `discount.go`, `invoice.go`, `tax.go`, each with the collapsed chevron, and no `_test.go` row is listed

#### Scenario: Nest children are indented under the parent
- **WHEN** the tree is open on the `treeproj` fixture with `internal/billing` expanded, and `za` is pressed on the `invoice.go` row
- **THEN** `invoice.go` shows the expanded chevron, the next row is `invoice_test.go` with its icon 2 columns right of `invoice.go`'s icon and no chevron, and the row after it is `tax.go`

#### Scenario: Nest state survives a refresh
- **WHEN** the `invoice.go` nest is expanded and `R` is pressed in the tree
- **THEN** after the refresh `invoice_test.go` is still listed under `invoice.go`, and the `discount.go` nest is still collapsed

### Requirement: File tree nest state
Each tab SHALL keep `expanded_nests` separately from `expanded`, keyed by the parent's path relative to the root. Nest state SHALL not be stored in `expanded.json`. `zM` and rerooting SHALL clear it. Drawing SHALL drop a key whose parent is gone, is not a file, or has no child. File and folder moves SHALL migrate matching keys in every view of the root.

#### Scenario: Nest state is isolated between tabs
- **WHEN** two tabs show the same root, the `invoice.go` nest is expanded in the first tab, and the second tab is focused
- **THEN** `invoice_test.go` is listed only in the first tab and the second tab's `invoice.go` nest remains collapsed

#### Scenario: Fold all and reroot clear nest state
- **WHEN** the `invoice.go` nest is expanded, `zM` is pressed, and the tree is then rerooted by changing cwd to another fixture root
- **THEN** `expanded_nests` is empty after `zM` and remains empty after rerooting, while `expanded.json` contains no nest-parent key

#### Scenario: Drawing prunes stale nest state
- **WHEN** `expanded_nests` contains parents that are gone, are directories, or no longer have a child and the tree draws
- **THEN** all three parent keys are absent from `expanded_nests`

#### Scenario: Renaming a nest parent migrates its state
- **WHEN** the `invoice.go` nest is expanded and `r` renames it to `bill.go` together with a matching `bill_test.go`
- **THEN** the old relative key is absent, the `bill.go` key is present, and `bill_test.go` is listed under `bill.go`

#### Scenario: Renaming a folder migrates nest state in every view
- **WHEN** two tabs show the same root with the `invoice.go` nest expanded and `r` renames `internal/billing` to `internal/accounts` in one tab
- **THEN** both views replace the old nest key with `internal/accounts/invoice.go` and keep `invoice_test.go` listed

### Requirement: File tree nest actions
`file_tree.toggle_fold` SHALL toggle the nest of a parent row. On a child row, it and `file_tree.close_node` SHALL collapse the nest and move the cursor to the parent. `file_tree.close_node` on an expanded parent SHALL collapse it. `file_tree.open` SHALL open a parent's file without toggling. `file_tree.unfold_all` and `file_tree.fold_all` SHALL also expand and collapse nests. Following the current file and revealing a new file SHALL expand their nest.

#### Scenario: za toggles a nest
- **WHEN** `za` is pressed twice on the `invoice.go` row
- **THEN** after the first press `invoice_test.go` is listed under it, and after the second it is not

#### Scenario: h on a nested file closes its nest
- **WHEN** the `invoice.go` nest is expanded, the cursor is on `invoice_test.go`, and `h` is pressed
- **THEN** `invoice_test.go` is no longer listed and the cursor is on the `invoice.go` row

#### Scenario: Enter on a nest parent opens the file
- **WHEN** the cursor is on the collapsed `invoice.go` row and `<CR>` is pressed
- **THEN** the window right of the tree edits `internal/billing/invoice.go`, and the `invoice.go` nest is still collapsed

#### Scenario: Fold all and unfold all include nests
- **WHEN** `zR` is pressed in the tree on the `treeproj` fixture, then `zM`
- **THEN** after `zR` the rows include `discount_test.go`, `invoice_test.go`, `tax_test.go`, `money_test.go`, `price.test.ts`, `price.d.ts`, `package-lock.json` and `go.sum`, each under its parent; after `zM` none of them is listed

#### Scenario: Followed nested file expands its nest
- **WHEN** the tree is open on the `treeproj` fixture with every nest collapsed and `:edit internal/billing/invoice_test.go` runs in the editor window
- **THEN** the `invoice.go` nest is expanded and the tree cursor is on the `invoice_test.go` row

#### Scenario: Added nested file is revealed in its nest
- **WHEN** the cursor is on the collapsed `invoice.go` row and `file_tree.add` creates `invoice_mock.go`
- **THEN** the `invoice.go` nest is expanded, it lists `invoice_mock.go` and `invoice_test.go` in that order, and the cursor is on `invoice_mock.go`

#### Scenario: Renamed file is revealed in a collapsed nest
- **WHEN** the `invoice.go` nest is collapsed and `r` renames `notes.go` to `invoice_mock.go`
- **THEN** the `invoice.go` nest is expanded and the cursor is on `invoice_mock.go`

#### Scenario: Pasted file is revealed in a collapsed nest
- **WHEN** the `invoice.go` nest is collapsed and `p` pastes a copied `invoice_mock.go` into `internal/billing`
- **THEN** the `invoice.go` nest is expanded and the cursor is on `invoice_mock.go`

#### Scenario: Visual delete on a collapsed parent deletes only the parent
- **WHEN** the `discount.go` nest is collapsed, Visual `d` selects only its parent row, and the delete is confirmed
- **THEN** `discount.go` is deleted, `discount_test.go` still exists, and `discount_test.go` is listed as a plain row

#### Scenario: Following under a symlinked root expands the nest
- **WHEN** the tree root normalizes from `/var` to `/private/var`, every nest is collapsed, and the editor opens `internal/billing/invoice_test.go` through the `/var` spelling
- **THEN** the `invoice.go` nest is expanded and the tree cursor is on `invoice_test.go`

#### Scenario: Deleting a nest parent keeps its children
- **WHEN** the cursor is on the `discount.go` row and `file_tree.delete` deletes it after confirmation
- **THEN** `internal/billing/discount_test.go` still exists and is listed as a plain row of `internal/billing` without a chevron

### Requirement: File tree nest git tint
A parent file without its own git status SHALL show its name in the status its children give it, by the folder tint rule of the file tree. A parent's own status SHALL win. The tint SHALL be the same whether the nest is collapsed or expanded.

#### Scenario: Collapsed nest parent shows a changed child
- **WHEN** in a copy of the `treeproj` fixture a line is appended to `internal/billing/discount_test.go`, `discount.go` is unchanged, and the tree shows `internal/billing` with the `discount.go` nest collapsed
- **THEN** the `discount.go` name is drawn with `FileTreeGitModified`

#### Scenario: Nest parent keeps its own status
- **WHEN** in a copy of the `treeproj` fixture `git commit -m test -- internal/billing/tax_test.go` runs and a line is then appended to `tax_test.go`, so `tax.go` is added and `tax_test.go` is modified, and the tree shows `internal/billing`
- **THEN** the `tax.go` name is drawn with `FileTreeGitAdded`, not the modified tint its child would give, and once its nest is expanded `tax_test.go` is drawn with `FileTreeGitModified`

#### Scenario: Deleted unlisted child does not tint its parent
- **WHEN** a tracked nested child is deleted so git reports it but the child is absent from the folder listing, and its unchanged parent nest is collapsed
- **THEN** the parent name has no git-status highlight from that deleted child

### Requirement: File tree nesting screen
With the default rules, the tree SHALL look like the approved render.

#### Scenario: File tree nests match the approved render
- **WHEN** the editor is 100x30, a copy of the `treeproj` fixture without its ignored entries is on branch `feat/tax` with design.md Decision 8's git state, `file_tree.toggle` opens the tree, `cmd/server`, `internal/billing` and `web/src` are expanded, the `invoice.go` nest is expanded, the tree cursor is on `invoice.go`, and the right window edits `internal/billing/invoice.go` at line 17
- **THEN** the screen matches the approved render "Proposed — nests under a chevron"

## MODIFIED Requirements

### Requirement: Project tree folds
In the tree, `file_tree.toggle_fold` SHALL toggle a folder or nest-parent row and, on any other file row, collapse its folder and move the cursor to it. `file_tree.fold_all` SHALL collapse every folder and nest and put the cursor on the top-level row that contained the selection. `file_tree.unfold_all` SHALL expand every folder and nest below the root, stopping after 5000 rows with the WARN notification `Unfold all stopped at 5000 rows`.

#### Scenario: Project tree za on a file collapses its folder
- **WHEN** `internal` and `billing` are expanded, the `tax.go` nest is collapsed, the cursor is on the `tax.go` row and `za` is pressed in normal mode
- **THEN** the cursor remains on `tax.go` and `tax_test.go` is listed under it

#### Scenario: Project tree zM collapses every folder
- **WHEN** `cmd/server`, `internal`, `billing` and `web` are expanded, the cursor is on the `invoice.go` row and `zM` is pressed in normal mode
- **THEN** every folder row shows U+F460, the root row is expanded, and the cursor is on the `internal` row

#### Scenario: Project tree zR expands every folder
- **WHEN** only the root is expanded in a copy of the `treeproj` fixture and `zR` is pressed in normal mode
- **THEN** rows `ci.yml`, `main.go`, `invoice.go`, `money.go` and `price.ts` exist and every folder row shows U+F47C

#### Scenario: Project tree unfold all stops at the row limit
- **WHEN** the root holds 60 folders of 100 files each and `zR` is pressed in normal mode
- **THEN** the tree has at most 5001 rows and a WARN notification `Unfold all stopped at 5000 rows` is emitted
