# references Specification

## Purpose
Shows every usage of the symbol under the cursor in a grouped, previewable Find Usages view, for any language whose attached LSP client supports references.

## Requirements

### Requirement: Primary language test paths
The references scope module SHALL classify Go files ending `_test.go`, TypeScript and JavaScript files whose basename contains `.test.` or `.spec.` or whose path contains `__tests__`, Python files named `test_*.py`, `*_test.py`, or `conftest.py` or under `tests`, and Lua files ending `_spec.lua` or under `spec` or `tests` as test code.

#### Scenario: Go test paths
- **WHEN** `require("gleb.references.scope").is_test(path, "go")` is called for Go test and production filenames
- **THEN** only paths ending `_test.go` are reported as test code

#### Scenario: TypeScript and JavaScript test paths
- **WHEN** `is_test` is called with TypeScript or JavaScript filetypes for `.test.`, `.spec.`, `__tests__`, and ordinary source paths
- **THEN** the three test conventions are reported as test code and ordinary source paths are not

#### Scenario: Python test paths
- **WHEN** `is_test` is called with the Python filetype for `test_*.py`, `*_test.py`, `conftest.py`, `tests/`, and ordinary source paths
- **THEN** the four test conventions are reported as test code and ordinary source paths are not

#### Scenario: Lua test paths
- **WHEN** `is_test` is called with the Lua filetype for `*_spec.lua`, `spec/`, `tests/`, and ordinary source paths
- **THEN** the three test conventions are reported as test code and ordinary source paths are not

#### Scenario: Language conventions classify paths
- **WHEN** test detection is asked about `a/b_test.go`, `src/x.test.ts`, `src/y.spec.js`, `src/__tests__/z.js`, `pkg/test_a.py`, `pkg/b_test.py`, `pkg/conftest.py`, `lua/m_spec.lua`, `tests/unit/test_rows.lua`, `crates/core/tests/api.rs`, `t/run.bats`, `main.tftest.hcl` and `infra/tests/plan.tftest.hcl`
- **THEN** every one of them is test code

#### Scenario: Production paths are not test code
- **WHEN** test detection is asked about `cmd/main.go`, `src/x.ts`, `src/testing_utils.ts`, `pkg/contest.py`, `lua/gleb/references/scope.lua`, `src/lib.rs`, `bin/run.sh` and `main.tf`
- **THEN** none of them is test code

### Requirement: Remaining and generic test paths
The references scope module SHALL classify Rust paths under `tests`, Bash files ending `.bats` or under `test` or `tests`, and Terraform files ending `.tftest.hcl` or under `tests` as test code for explicit or inferred `terraform`, `tf`, and `hcl` filetypes. For any language, a `test`, `tests`, `spec`, or `__tests__` path segment SHALL be test code. It SHALL infer the applicable language from the path when no filetype is supplied.

#### Scenario: Rust test paths
- **WHEN** `is_test` is called with the Rust filetype for paths inside and outside a `tests` segment
- **THEN** only paths inside `tests` are reported as test code

#### Scenario: Bash test paths
- **WHEN** `is_test` is called with the Bash filetype for `.bats`, `test/`, `tests/`, and ordinary shell paths
- **THEN** the three test conventions are reported as test code and ordinary shell paths are not

#### Scenario: Terraform test paths
- **WHEN** `is_test` is called with a Terraform filetype for `.tftest.hcl`, `tests/`, and ordinary Terraform paths
- **THEN** the two test conventions are reported as test code and ordinary Terraform paths are not

#### Scenario: Generic and inferred test paths
- **WHEN** `is_test` is called for configured filetypes with generic test segments, or without a filetype for paths whose extension identifies a primary language
- **THEN** generic test segments and inferred language conventions are reported as test code while ordinary source paths are not

#### Scenario: Unknown languages use the generic segments
- **WHEN** test detection is asked about `app/spec/models/user.rb` and `app/models/user.rb` with filetype `ruby`
- **THEN** only `app/spec/models/user.rb` is test code

### Requirement: Project test-pattern extensions
The references scope module SHALL append the Lua patterns in `vim.g.gleb_test_patterns[filetype]` to that filetype's built-in conventions. The built-in convention table SHALL remain the single source for default patterns, and missing or unrelated extension entries SHALL not change classification.

#### Scenario: Project pattern extends one filetype
- **WHEN** `vim.g.gleb_test_patterns` adds a pattern for one filetype and `is_test` is called for matching and nonmatching paths in that and another filetype
- **THEN** the matching path in the configured filetype is test code, built-in conventions still work, and the extension does not affect the other filetype

#### Scenario: A project adds its own test pattern
- **WHEN** `vim.g.gleb_test_patterns = { go = { "/e2e/" } }` is set and test detection is asked about `svc/e2e/flow.go` and `svc/flow_test.go`
- **THEN** both are test code

### Requirement: Rust inline test modules
For Rust source, `is_test_at(path, lnum, text)` SHALL report positions within a `#[cfg(test)]` module as test code by parsing the supplied text with Tree-sitter. Path-based test classification SHALL still apply. If the Rust parser is unavailable or parsing fails, the function SHALL not error and SHALL use path-based classification only.

#### Scenario: Position inside Rust cfg test module
- **WHEN** `is_test_at` receives Rust source containing a `#[cfg(test)]` module and positions inside and outside that module while the Rust parser is available
- **THEN** the inside position is reported as test code and the outside position is not

#### Scenario: Rust parser unavailable
- **WHEN** `is_test_at` receives Rust source containing a `#[cfg(test)]` module while the Rust parser is unavailable
- **THEN** it does not error, does not classify the position from source text, and still reports a path under `tests` as test code

### Requirement: Find Usages view opens on gr
Normal-mode `gr` SHALL request `textDocument/references` (declaration excluded) from the attached clients that support it and open the Find Usages view for the symbol under the cursor. A client that refuses the request SHALL count as returning no usages and SHALL NOT prevent accepted requests from completing. When no attached client supports references, or no usages are returned, it SHALL notify at INFO level (`No LSP references support` / `No usages found`) and open no window.

#### Scenario: gr opens the view in a Go module
- **WHEN** Neovim runs in a fresh copy of the `gomod` fixture with `internal/money/money.go` open, the cursor on the `Format` declaration, gopls attached, and `gr` is pressed in normal mode
- **THEN** a Find Usages view is open whose top border title is `Usages of Format · 4`

#### Scenario: gr with no usages notifies and opens nothing
- **WHEN** the cursor is on a local variable that has no usages and `gr` is pressed in normal mode
- **THEN** `No usages found` is notified at INFO level and the window count is unchanged

#### Scenario: gr without a references-capable client notifies
- **WHEN** a buffer with no attached LSP client is current and `gr` is pressed in normal mode
- **THEN** `No LSP references support` is notified at INFO level and the window count is unchanged

#### Scenario: gr continues when one client refuses the request
- **WHEN** Neovim runs in a fresh copy of the `gomod` fixture with `internal/money/money.go` open, the cursor on the `Format` declaration, two references-capable clients attached, one client refuses its `textDocument/references` request, and `gr` is pressed in normal mode
- **THEN** a Find Usages view is open whose top border title is `Usages of Format · 4`

### Requirement: Find Usages layout
With the preview shown, the view SHALL be a centred rounded float covering the editor except two columns per side and the bufferline and statusline rows, with the tree on the left (45% of the inner width) and the preview on the right. Without the preview it SHALL shrink to its content and stay centred. Hints SHALL sit on the last inner row below a joined rule. Below 80 editor columns the preview SHALL start hidden.

#### Scenario: Wide view matches reference screenshot
- **WHEN** `gr` is pressed on `Format` in the `gomod` fixture with the editor at 100x30 and default grouping, and classification has finished
- **THEN** the screen matches the approved render "Proposed V1 — default grouping"

#### Scenario: Narrow view fits its content
- **WHEN** `gr` is pressed on `Format` in the `gomod` fixture with the editor at 70x24, and classification has finished
- **THEN** the view has no preview pane, is only as wide and tall as its rows and hints need, is centred, and the screen matches the approved render "Proposed V4 — no preview"

#### Scenario: View reflows when the editor resizes
- **WHEN** an open wide view is resized wider and then below 80 editor columns
- **THEN** its frame is recentered at each size and it switches to the fitted layout without a preview below 80 columns

### Requirement: Usage tree grouping
The tree SHALL group usages by test scope (`Production` before `Test`, from test-file detection), then by usage type when that level is shown, then by folder, with one row per folder showing its full path relative to the working directory (no nested folder rows), ordering rows by path then line. Group rows SHALL show their usage count. Usage rows SHALL show only `<file name>:<line>`.

#### Scenario: Go usages are grouped by scope and folder
- **WHEN** the view is open for `Format` in the `gomod` fixture with default grouping and classification has finished
- **THEN** the tree rows are, in order: `Production 3`, `Call 3`, `billing 2`, `invoice.go:16`, `invoice.go:23`, `report 1`, `summary.go:7`, `Test 1`, `Call 1`, `internal/money 1`, `money_test.go:6`

#### Scenario: Nested folders become one row
- **WHEN** the view lists usages in `internal/provisioner/postgres/deprovision.go` and `internal/provisioner/postgres/provision.go`
- **THEN** a single folder row `internal/provisioner/postgres 2` holds both usage rows and no row exists for `internal` or `internal/provisioner`

#### Scenario: The first usage is selected and previewed
- **WHEN** the view opens for `Format` in the `gomod` fixture
- **THEN** the cursor is on the `invoice.go:16` row and the preview shows `billing/invoice.go` centred on line 16

### Requirement: Tree icons and colours
Production rows SHALL show the oct-rocket glyph (U+F427) in aqua, Test rows the oct-beaker glyph (U+F499) in yellow, folder rows the md-folder_outline glyph (U+F0256) in grey, and usage rows their file's devicon in its colour. Each label SHALL use a paler shade of its icon colour, the palette mix of icon colour and foreground at 0.7; counts and `:<line>` SHALL use the secondary picker highlight.

#### Scenario: Icons and label shades match the palette
- **WHEN** the view is open for `Format` and the extmarks of the `Production 3`, `Test 1`, `billing 2` and `invoice.go:16` rows are read
- **THEN** each icon cell uses its icon group (aqua, yellow, grey, the Go devicon colour) and each label uses a group whose foreground equals the 0.7 mix of that icon colour and the palette foreground

#### Scenario: Label shade is the 0.7 mix of icon and foreground
- **WHEN** the label colour is computed for icon colour `#000000` and foreground `#646464`
- **THEN** it is `#464646`, 70% of the way from the icon colour to the foreground

### Requirement: Grouping controls
`t` SHALL cycle the tests mode: grouped (`Production`/`Test` level), hidden (test usages removed), mixed (no scope level; test usages carry a right-aligned beaker `test` tag). `f` SHALL toggle `Folders` (off: usage rows show the path relative to the working directory, shortened from the left with `…` when a tag needs the room). Each change SHALL rebuild the tree in place, keep the selected usage, update counts and title, show its state in the hint row and persist across sessions.

#### Scenario: Tests key cycles grouped, hidden and mixed
- **WHEN** the view is open for `Format` with default grouping after classification and `t` is pressed three times
- **THEN** after the first press the screen matches the approved render "Proposed V2 — tests hidden"; after the second there are no `Production` or `Test` rows, `money_test.go:6` carries the `test` tag and the hint row shows `Tests: mixed t`; after the third the tree equals the default one

#### Scenario: Mixed tests without folders is a flat list
- **WHEN** the view is open for `Format` with default grouping after classification and `t`, `t`, `f` are pressed
- **THEN** the screen matches the approved render "Proposed V3 — tests mixed, folders off"

#### Scenario: Grouping persists across sessions
- **WHEN** `t` and `f` are pressed once in the view, Neovim is restarted, and the view is opened again for `Format`
- **THEN** the hint row shows `Tests: hidden t` and `○ Folders f`, and no `Test` group is listed

#### Scenario: Regrouping keeps the selected usage
- **WHEN** the cursor is on the `summary.go:7` row and `f` is pressed
- **THEN** the cursor is on the `report/summary.go:7` row in the rebuilt tree

#### Scenario: Tests filter can leave the tree empty
- **WHEN** every usage is in a test file and the tests mode becomes or is persisted as hidden
- **THEN** the view remains open with count zero, a one-row tree, and no stale preview

### Requirement: Usage preview
The preview SHALL show the selected usage's file around its line, centred, with line numbers and the same syntax highlighting a regular buffer of that filetype gets (treesitter when its parser is installed, else the Vim syntax file). The usage's line number SHALL use the current-line-number highlight and every listed usage in the file SHALL be marked.

#### Scenario: Preview follows the selection
- **WHEN** the view is open for `Format` and the cursor moves to the `summary.go:7` row
- **THEN** the preview shows `report/summary.go` centred on line 7 with its line number highlighted and `Format` marked on it

#### Scenario: UTF-16 usage columns are converted to byte columns
- **WHEN** a usage follows a multibyte character and its LSP client reports UTF-16 positions
- **THEN** the preview mark and Return cursor are on the first byte of the usage

#### Scenario: Preview highlighting matches a regular buffer
- **WHEN** the preview shows `billing/invoice.go` around line 16
- **THEN** the treesitter highlight captures at every column of preview lines 11 to 16 equal the captures at the same positions in a regular buffer editing `billing/invoice.go`

#### Scenario: Preview falls back to Vim syntax without a parser
- **WHEN** the preview shows a file whose filetype has no installed treesitter parser but a Vim syntax file
- **THEN** the preview buffer's `syntax` option is that filetype and no treesitter highlighter is active for it

#### Scenario: P toggles the preview pane
- **WHEN** the view is open at 100x30 with the preview visible and `P` is pressed
- **THEN** the preview pane is closed, the window shrinks to its content as in the narrow layout, and pressing `P` again restores the wide layout

### Requirement: Preview has no side effects
The preview SHALL read the loaded buffer's text when the file is loaded, else the file on disk, and SHALL NOT load a buffer, attach an LSP client or create a swap file.

#### Scenario: Preview leaves no buffer or client behind
- **WHEN** the view is open for `Format`, every usage row is selected once, and the view is closed
- **THEN** the buffer list and the number of buffers attached to gopls equal those before `gr` was pressed

#### Scenario: Preview shows unsaved edits
- **WHEN** `billing/invoice.go` is loaded with an unsaved edit on line 15 and the `invoice.go:16` row is selected
- **THEN** the preview shows the edited line 15

### Requirement: Find Usages navigation keys
The view's keys SHALL be registry actions scoped to the view, bound from `settings/keymap.json`: `<CR>` opens the selected usage (or folds/unfolds a group row), `za` folds/unfolds the group under the cursor, `q` and `<Esc>` close the view. Opening a usage SHALL close the view and place the cursor on the usage; closing SHALL return to the window the view was opened from.

#### Scenario: Return opens a usage at its position
- **WHEN** the cursor is on the `summary.go:7` row and Return is pressed
- **THEN** the view is closed, the current buffer is `report/summary.go`, and the cursor is at line 7 on the `Format` call

#### Scenario: za folds a group
- **WHEN** the cursor is on the `billing 2` row and `za` is pressed
- **THEN** the `invoice.go:16` and `invoice.go:23` rows are hidden, and pressing `za` again shows them

#### Scenario: Escape returns to the origin window
- **WHEN** the view was opened from `internal/money/money.go` and Escape is pressed
- **THEN** no view window remains and the current window shows `internal/money/money.go` with the cursor where `gr` was pressed

#### Scenario: Built-in close returns to the origin window
- **WHEN** the view was opened from `internal/money/money.go` and the tree window is closed with `:quit`
- **THEN** no view window remains, resize handling is removed, and the current window shows `internal/money/money.go` with the cursor where `gr` was pressed

#### Scenario: View keys come from the keymap file
- **WHEN** the view buffer is current and its buffer-local normal-mode mappings are read
- **THEN** each of `<CR>`, `za`, `t`, `f`, `u`, `P`, `q` and `<Esc>` has a `desc` naming a registered `references.*` action, `settings/keymap.json` lists that action with that key, and no buffer-local `w` mapping exists

### Requirement: Find Usages in every configured language
`gr` SHALL open the Find Usages view with every usage the attached server reports, grouped by test scope, usage type when shown, and folder, for Lua (lua_ls), Python (basedpyright), TypeScript (vtsls), Rust (rust-analyzer), Bash (bashls) and Terraform (terraform-ls), as for Go. When a buffer has several attached clients, only those advertising `referencesProvider` SHALL be asked and each usage SHALL be listed once.

#### Scenario: Lua usages in production and spec files
- **WHEN** Neovim runs in a fresh copy of the `luaproj` fixture with `lua/shop/price.lua` open, the cursor on the `M.total` definition, lua_ls attached, and `gr` is pressed
- **THEN** the view lists `cart.lua:<line>` under `Production` in folder `lua/shop` and `price_spec.lua:<line>` under `Test` in folder `spec`, at the fixture manifest's lines, whatever usage type groups sit between scope and folder

#### Scenario: Python usages in production and test files
- **WHEN** Neovim runs in a fresh copy of the `pyproj` fixture with `shop/price.py` open, the cursor on the `total` definition, basedpyright and ruff attached, and `gr` is pressed
- **THEN** the view lists `cart.py:<line>` under `Production` in folder `shop` and `test_price.py:<line>` under `Test` in folder `tests`, at the manifest's lines, each once, whatever usage type groups sit between scope and folder

#### Scenario: TypeScript usages in production and test files
- **WHEN** Neovim runs in a fresh copy of the `tsproj` fixture with `src/price.ts` open, the cursor on the exported `total` function, vtsls and eslint attached, and `gr` is pressed
- **THEN** the view lists `cart.ts:<line>` under `Production` in folder `src` and `price.test.ts:<line>` under `Test` in folder `src`, at the manifest's lines, each once, whatever usage type groups sit between scope and folder

#### Scenario: Rust usages in production and test code
- **WHEN** Neovim runs in a fresh copy of the `rustproj` fixture with `src/price.rs` open, the cursor on the `pub fn total` definition, rust-analyzer attached, and `gr` is pressed
- **THEN** the view lists the `src/main.rs` usage under `Production` and the `tests/price.rs` usage under `Test`; the usage inside `#[cfg(test)] mod tests` of `src/price.rs` is under `Test` when the `rust` parser is installed and under `Production` otherwise

#### Scenario: Bash usages in production and test scripts
- **WHEN** Neovim runs in a fresh copy of the `bashproj` fixture with `lib/price.sh` open, the cursor on the `total` function, bashls attached, and `gr` is pressed
- **THEN** the view lists `run.sh:<line>` under `Production` in folder `bin` and `price_test.sh:<line>` under `Test` in folder `test`, at the manifest's lines, whatever usage type groups sit between scope and folder

#### Scenario: Terraform variable usages
- **WHEN** Neovim runs in a fresh copy of the `tfproj` fixture with `variables.tf` open, the cursor on `variable "region"`, terraform-ls attached, and `gr` is pressed
- **THEN** the view lists `Production` with the `main.tf` and `outputs.tf` usages at the manifest's lines and no `Test` group

#### Scenario: Two attached clients list each usage once
- **WHEN** usages are requested for a buffer with two attached clients that both advertise `referencesProvider` and both return the same locations
- **THEN** each location appears as exactly one usage row

### Requirement: Usage type classification
Every usage listed by `gr` SHALL get one catalogue type: the type the filetype's `usages` treesitter query captures at the usage's start (lowest pattern wins) unless target-kind rules drop it; else the server's `write`/`read`; else the query's `write`/`read` fallback; else `unclassified`. Current-file write highlights omitted from references SHALL be added except at the origin. Without a parser, only server kinds apply.

#### Scenario: gopls kinds classify a Go variable
- **WHEN** usages of `Calls` in the extended `gomod` fixture are classified with gopls attached
- **THEN** `report/calls.go:8` and `report/calls_test.go:6` are `write`, and `report/calls_test.go:8` and `:9` are `read`

#### Scenario: lua_ls kinds classify a Lua local
- **WHEN** usages of `count` are classified in a temporary Lua file `local count = 0` / `count = count + 1` / `print(count)` with lua_ls attached
- **THEN** the usage on line 2 at column 1 is `write`, and the usages on line 2 after `=` and on line 3 are `read`

#### Scenario: basedpyright kinds classify a Python variable
- **WHEN** usages of `total` are classified in a temporary Python module `total = 0` / `total += 1` / `print(total)` with basedpyright attached
- **THEN** the usage on line 2 is `write` and the usage on line 3 is `read`

#### Scenario: tsserver kinds classify a TypeScript variable
- **WHEN** usages of `hits` are classified in a temporary TypeScript project `let hits = 0;` / `hits++;` / `console.log(hits);` with vtsls attached
- **THEN** the usage on line 2 is `write` and the usage on line 3 is `read`

#### Scenario: rust-analyzer kinds classify a Rust variable
- **WHEN** usages of `n` are classified in a temporary Cargo crate whose `main` has `let mut n = 0;` / `n += 1;` / `println!("{n}");` with rust-analyzer attached
- **THEN** the usage on line 2 is `write` and the usage on line 3 is `read`

#### Scenario: Treesitter fallback classifies writes where a parser exists
- **WHEN** the treesitter fallback classifies the target identifier in `x := 1` and `x++` (Go), `x = 1` (Lua), `x=1` (Bash), and `print(x)` / `echo "$x"` in each
- **THEN** every assignment, declaration and increment target is `write` and every non-target variable use is `read`

#### Scenario: Without kinds or a parser a usage is other
- **WHEN** a usage is classified for a file whose client offers no kinds and whose filetype has no installed parser
- **THEN** no error is raised and the usage is `unclassified`, the type that replaces `other`

#### Scenario: Go query classifies every GoLand usage type
- **WHEN** the Go `usages` query classifies each position of the Go draft case table (`drafts/cases.lua`, Go entries) with the installed `go` parser and the case's target kind
- **THEN** every position gets the expected type, renamed per the catalogue (`value_write` is `write`), and every negative case gets no syntactic type

#### Scenario: gr classifies struct usages
- **WHEN** Neovim runs in a fresh copy of the extended `gomod` fixture with the cursor on the `Invoice` declaration, gopls attached, and `gr` is pressed in normal mode
- **THEN** the view lists `billing/batch.go:5` and `:6` as `field_declaration`, `:10` as `return_type`, `:11` as `struct_initialization`, `:15` once as `parameter_declaration` and once as `return_type`, `billing/invoice.go:11` and `:20` as `receiver`, and `billing/invoice_test.go:6` as `struct_initialization`

#### Scenario: gr classifies function usages as calls
- **WHEN** Neovim runs in a fresh copy of the `gomod` fixture with the cursor on the `Format` declaration, gopls attached, and `gr` is pressed in normal mode
- **THEN** every listed usage is `call`

#### Scenario: Composite literal keys are field writes
- **WHEN** Neovim runs in a fresh copy of the extended `gomod` fixture with the cursor on the `Lines` field declaration, gopls attached, and `gr` is pressed in normal mode
- **THEN** the `Lines:` keys in `billing/batch.go:11` and `billing/invoice_test.go:6` and the assignment target in `billing/batch.go:16` are `write`, and `i.Lines` in `billing/invoice.go:13` and `:22` and the `inv.Lines` argument in `billing/batch.go:16` are `read`

#### Scenario: gr classifies every Go variable usage
- **WHEN** Neovim runs in a fresh copy of the extended `gomod` fixture with the cursor on the `Calls` declaration in `report/calls.go`, gopls attached, and `gr` is pressed in normal mode
- **THEN** the view lists `report/calls.go:8` and `report/calls_test.go:6` as `write`, and `report/calls_test.go:8` and `report/calls_test.go:9` as `read`

#### Scenario: gr classifies every Lua local usage
- **WHEN** Neovim opens a temporary Lua project containing `local count = 0` / `count = count + 1` / `print(count)`, lua_ls is attached, the cursor is on the declaration, and `gr` is pressed in normal mode
- **THEN** the view lists line 2 column 1 as `write`, and line 2 after `=` and line 3 as `read`

#### Scenario: gr classifies every Python variable usage
- **WHEN** Neovim opens a temporary Python project containing `total = 0` / `total += 1` / `print(total)`, basedpyright is attached, the cursor is on the declaration, and `gr` is pressed in normal mode
- **THEN** the view lists line 2 as `write` and line 3 as `read`

#### Scenario: gr classifies every TypeScript variable usage
- **WHEN** Neovim opens a temporary TypeScript project containing `let hits = 0;` / `hits++;` / `console.log(hits);`, vtsls is attached, the cursor is on the declaration, and `gr` is pressed in normal mode
- **THEN** the view lists line 2 as `write` and line 3 as `read`

#### Scenario: gr classifies every Rust variable usage
- **WHEN** Neovim opens a temporary Cargo crate whose `main` contains `let mut n = 0;` / `n += 1;` / `println!("{n}");`, rust-analyzer is attached, the cursor is on the declaration, and `gr` is pressed in normal mode
- **THEN** the view lists line 2 as `write` and line 3 as `read`

#### Scenario: gr classifies every Bash variable usage
- **WHEN** Neovim opens a temporary Bash project containing `count=0` / `count=$((count + 1))` / `printf '%s\n' "$count"`, bashls is attached, the cursor is on the declaration, and `gr` is pressed in normal mode
- **THEN** the view lists the assignment on line 2 as `write` and both non-target occurrences as `read`

#### Scenario: gr classifies every Terraform variable usage
- **WHEN** Neovim runs in a fresh copy of the `tfproj` fixture with terraform-ls attached, the cursor on `variable "region"`, and `gr` is pressed in normal mode
- **THEN** the view lists the `var.region` traversals in `main.tf` and `outputs.tf` as `read`

#### Scenario: HCL fallback classifies variable labels and traversals
- **WHEN** the treesitter fallback classifies `region` in `variable "region" {}` and in `value = var.region`
- **THEN** the variable block label is `write` and the traversal is `read`

#### Scenario: Rust query classifies every usage type
- **WHEN** the Rust `usages` query classifies each position of the case table `tests/unit/references/usage_cases/rust.lua` in its source `usage_cases/rust/usages.rs` with the installed `rust` parser and the case's target kind
- **THEN** every position gets its expected catalogue id (`trait_bound` is `type_constraint`, `method_call` is `call`, `dot` is `field_access`, `trait_impl` is `extends`, `type_argument` is `type_instantiation`), a field assignment target is `write`, and every negative case gets no syntactic type

#### Scenario: gr classifies Rust struct usages
- **WHEN** Neovim runs in a fresh copy of the extended `rustproj` fixture with the cursor on the `Money` declaration in `src/money.rs`, rust-analyzer attached and quiescent, and `gr` is pressed in normal mode
- **THEN** the view lists `src/ledger.rs:1` and `tests/money.rs:1` as `import`, `src/ledger.rs:4` and `src/money.rs:7` as `return_type`, `src/ledger.rs:5` and `tests/money.rs:5` as `call`, `src/ledger.rs:9` as `parameter_declaration`, `src/ledger.rs:11` as `pattern`, `src/money.rs:6` as `impl` and `src/money.rs:8` as `struct_initialization`

#### Scenario: gr classifies Rust field usages
- **WHEN** Neovim runs in a fresh copy of the extended `rustproj` fixture with the cursor on the `cents` field declaration in `src/money.rs`, rust-analyzer attached and quiescent, and `gr` is pressed in normal mode
- **THEN** the view lists `src/ledger.rs:11` as `pattern`, `src/money.rs:8` as `field_initialization` and `tests/money.rs:6` as `macro_argument`

### Requirement: Asynchronous classification
The view SHALL open with scope and folder grouping as soon as references arrive, show `Usages of <symbol> · <count> · classifying` in its title while classification runs (at most 3 seconds), and rebuild with the usage type level when it finishes, keeping the selected usage.

#### Scenario: The view opens before classification finishes
- **WHEN** `gr` is pressed on `Calls` with documentHighlight responses delayed by a test hook
- **THEN** the view is open with title `Usages of Calls · 4 · classifying` and no usage type rows, and after the responses arrive the title is `Usages of Calls · 4` with `Value read` and `Value write` rows and the same selected usage

#### Scenario: Classification gives up after the timeout
- **WHEN** documentHighlight never answers for a file
- **THEN** after 3 seconds the title drops `· classifying`, the remaining usages are classified by the query and its fallback, and nothing is reported as an error

### Requirement: Usage type grouping
When at least one listed usage is not `unclassified`, the tree SHALL add a usage type level between test scope and folder, with one group per type present, labelled as in the usage type catalogue and ordered by label in byte order (`Value read` before `Value write`, `Unclassified` among them by spelling). Each group SHALL show its count, its type's icon in the icon colour and its label in the 0.7 paler shade. When every usage is `unclassified`, the level and its hint SHALL be omitted.

#### Scenario: Variable usages are grouped by write and read
- **WHEN** `gr` is pressed on the `Calls` declaration in `report/calls.go` of the extended `gomod` fixture with gopls attached, the editor at 100x30 and default grouping, and classification has finished
- **THEN** the screen matches the approved render "Proposed K1 — value usages"

#### Scenario: Struct usages are grouped by usage type
- **WHEN** `gr` is pressed on the `Invoice` declaration in `billing/invoice.go` of the extended `gomod` fixture with gopls attached, the editor at 100x30 and default grouping, and classification has finished
- **THEN** the screen matches the approved render "Proposed T1 — usage types of a struct"

#### Scenario: Function usages are grouped under Call
- **WHEN** the view is open for `Format` in the `gomod` fixture and classification has finished
- **THEN** `Production` holds one `Call 3` group and `Test` one `Call 1` group, no `Value write` or `Value read` rows exist, and the hint row shows `● Usage type u`

#### Scenario: Unclassified usages add no level
- **WHEN** the tree is built from usages that are all `unclassified`
- **THEN** no usage type rows exist and the hint row has no `Usage type` entry

#### Scenario: Usage type groups sort by label
- **WHEN** the tree is built from one usage of each of `write`, `read`, `unclassified`, `call`, `struct_initialization` and `field_declaration`
- **THEN** the type groups are, in order: `Call`, `Field declaration`, `Struct initialization`, `Unclassified`, `Value read`, `Value write`

#### Scenario: Usage type icons and label shades match the palette
- **WHEN** the view is open for `Invoice` after classification and the extmarks of the `Field declaration 2`, `Receiver 2` and `Struct initialization 1` rows are read
- **THEN** each icon cell uses its type's icon group with the catalogue colour, and each label uses a group whose foreground equals the 0.7 mix of that colour and the palette foreground

#### Scenario: Rust struct usages are grouped by usage type
- **WHEN** `gr` is pressed on the `Money` declaration in `src/money.rs` of the extended `rustproj` fixture with rust-analyzer attached, the editor at 70x36 and default grouping, and classification has finished
- **THEN** the screen matches the approved render "Proposed R1 — usage types of a Rust struct"

### Requirement: Usage type toggle
When the usage type level is available, `u` SHALL toggle it, the hint row SHALL show `●`/`○ Usage type u`, and the state SHALL persist across sessions; a persisted state saved before this key existed SHALL be honoured. With the level off, each usage row whose type is not `unclassified` SHALL carry a right-aligned tag: its type's icon in the icon colour and the type's short name.

#### Scenario: u turns the level into row tags
- **WHEN** the view is open for `Calls` with default grouping after classification and `u` is pressed
- **THEN** the screen matches the approved render "Proposed K2 — usage type off"

#### Scenario: u turns struct usage types into row tags
- **WHEN** the view is open for `Invoice` with default grouping after classification and `u` is pressed
- **THEN** the screen matches the approved render "Proposed T2 — struct, usage type off"

#### Scenario: Real key presses switch Calls usages from the level to row tags
- **WHEN** Neovim runs in a fresh copy of the extended `gomod` fixture at 100x30 with the cursor on the `Calls` declaration in `report/calls.go` and gopls attached, `g` `r` is pressed as a real key press, classification finishes, and `u` is pressed as a real key press
- **THEN** the view first shows the rows of "Proposed K1 — value usages" with `● Usage type u` in the hint, then the rows of "Proposed K2 — usage type off" with `○ Usage type u`

#### Scenario: Usage type state persists across sessions
- **WHEN** `u` is pressed in the view for `Calls`, Neovim is restarted, and the view is opened again for `Calls`
- **THEN** the hint row shows `○ Usage type u` and no `Value write` or `Value read` rows exist

#### Scenario: A saved read/write state carries over
- **WHEN** the references state file holds `{"read_write": false}` only and the view is opened for `Calls`
- **THEN** the hint row shows `○ Usage type u`, and the state file then holds `"usage_type": false`

#### Scenario: The usage type key comes from the keymap file
- **WHEN** the view buffer is current and its buffer-local normal-mode mapping for `u` is read
- **THEN** its `desc` names the registered `references.toggle_usage_type` action and `settings/keymap.json` lists that action with `u` and has no `references.toggle_read_write` entry

### Requirement: Usage type catalogue
The config SHALL define one usage type catalogue, the single source for type ids, labels, icons, icon colours and tags; every `@usage.<id>` capture in any `usages` query on the runtimepath SHALL name a catalogue id. Labels SHALL follow GoLand's wording, including `Value read`, `Value write` and `Unclassified`, and each Go type SHALL carry GoLand's label.

#### Scenario: Every query capture is in the catalogue
- **WHEN** every `queries/*/usages.scm` file in the config is parsed with its parser language (a file for a name with no parser, such as an inherited base, through the files that inherit it) and its capture names are listed
- **THEN** each name is a helper starting with `_` or `usage.<id>` with `<id>` in the catalogue

#### Scenario: Go types carry GoLand labels
- **WHEN** the catalogue labels of the Go query's ids are read
- **THEN** they are `Call`, `Const declaration`, `Field declaration`, `Function argument`, `Import`, `Parameter declaration`, `Receiver`, `Return type`, `Struct initialization`, `Type alias`, `Type assertion`, `Type constraint`, `Type conversion`, `Type instantiation`, `Type parameter declaration`, `Variable declaration`, `Value read` and `Value write`

### Requirement: Target kind refines usage types
The searched symbol's kind (function, type, field, variable or unknown, from its definition's document symbol; a variable named by a type identifier is a type) SHALL refine types: function and type targets get no `write`/`read`; `function_argument` needs a function target and `static_member` a type target; a Go `call` of a type target is `type_conversion`; a known non-type target drops type-position types; an unknown target drops only `function_argument` and `static_member`.

#### Scenario: A Go conversion of a type is a type conversion
- **WHEN** the Go query classifies `Money(x)` with target kind `type`, and again with target kind `function`
- **THEN** the first is `type_conversion` and the second is `call`

#### Scenario: A function passed as a value is a function argument
- **WHEN** the Go query classifies `less` in `sort.Slice(xs, less)` with target kind `function`, and again with target kind `variable`
- **THEN** the first is `function_argument` and the second has no syntactic type and falls back to `read`

#### Scenario: A variable named by a type identifier is a type target
- **WHEN** the target's document symbol kind is Variable and the node naming it at its definition is a treesitter `type_identifier` (a TypeScript `type Amount = number`)
- **THEN** the target kind is `type`

#### Scenario: Terraform blocks are not type targets
- **WHEN** the target's document symbol kind is Class in a `terraform` buffer (terraform-ls reports `variable "region"` as Class)
- **THEN** the target kind is `unknown`, so its `var.region` traversals keep `read`

#### Scenario: Function and type targets get no write or read
- **WHEN** a usage of a target of kind `function` or `type` has a server `read` kind and no syntactic type
- **THEN** it is `unclassified`

### Requirement: TypeScript usage types
For TypeScript, TSX and JavaScript files, each parsed with its own filetype's parser, the `usages` queries SHALL classify `call`, `import`, `new`, `static_member`, `extends`, `cast`, `instanceof`, `field_declaration`, `variable_declaration`, `parameter_declaration`, `catch`, `return_type`, `type_instantiation` and `type_alias`. A target whose document symbol is Variable or Constant but whose definition name is a `type_identifier` SHALL be a `type` target.

#### Scenario: TypeScript query classifies every usage type
- **WHEN** the case table `tests/unit/references/usage_cases/js.lua` runs with the installed `typescript`, `tsx` and `javascript` parsers, each case with its target kind (`unknown` when none is given)
- **THEN** every position gets its expected catalogue type, and every negative case gets no syntactic type

#### Scenario: TSX and TypeScript buffers use their own parser
- **WHEN** the query runner classifies `Money` in a `typescriptreact` buffer holding `const price = <Price value={new Money(1)} />;` and in a `typescript` buffer holding `const m = <Money>raw;`
- **THEN** the first is `new` and the second is `cast`

#### Scenario: gr classifies TypeScript class usages
- **WHEN** Neovim runs in a fresh copy of the extended `tsproj` fixture with the cursor on the `Money` declaration in `src/money.ts`, vtsls attached and its references reply holding all 15 manifest usages, and `gr` is pressed in normal mode
- **THEN** the view lists `src/money.ts:10` as `return_type`, `:11` as `new`, `:16` and `:17` as `instanceof`, `src/wallet.ts:1` as `import`, `:3` as `extends`, `:6` as `field_declaration`, `:8` as `parameter_declaration`, `:13` as `return_type`, `:14` as `cast`, `:19` once as `variable_declaration` and once as `static_member`, `src/money.test.ts:1` as `import`, and `:3` once as `type_instantiation` and once as `static_member`

#### Scenario: gr classifies TypeScript method usages as calls
- **WHEN** Neovim runs in a fresh copy of the extended `tsproj` fixture with the cursor on `parse` in `src/money.ts` line 10, vtsls attached, and `gr` is pressed in normal mode
- **THEN** the view lists exactly `src/wallet.ts:19` and `src/money.test.ts:3`, both as `call`

#### Scenario: TypeScript type alias targets keep their usage types
- **WHEN** Neovim opens a temporary TypeScript project containing `type Amount = number;` / `const rate: Amount = 1;` / `function convert(a: Amount): Amount {` / `  return a * rate;` / `}` / `convert(2);`, vtsls is attached, the cursor is on `Amount` in line 1, and `gr` is pressed in normal mode
- **THEN** the view lists line 2 as `variable_declaration` and line 3 once as `parameter_declaration` and once as `return_type`, and no usage is `read`

#### Scenario: TypeScript class usages are grouped by usage type
- **WHEN** `gr` is pressed on the `Money` declaration in `src/money.ts` of the extended `tsproj` fixture with vtsls attached, the editor at 70x50 and default grouping, and classification has finished
- **THEN** the screen matches the approved render "Proposed P1 — TypeScript usage types of a class"

### Requirement: Python usage types
Python usages SHALL be classified by `queries/python/usages.scm` as `import`, `decorator`, `extends`, `instanceof`, `catch`, `keyword_argument`, `call`, `pattern`, `parameter_declaration`, `field_declaration`, `variable_declaration`, `type_alias` or `return_type`, with assignment targets captured as the `write` fallback. The target-kind rules SHALL apply, and a Python `call` of a `type` target SHALL be `new`.

#### Scenario: Python query classifies every usage type
- **WHEN** the Python `usages` query classifies each position of the case table `tests/unit/references/usage_cases/python.lua` with the installed `python` parser and the case's target kind
- **THEN** every position gets its expected catalogue type, and every negative case gets no syntactic type

#### Scenario: A Python call of a class is a new instance creation
- **WHEN** the Python query classifies `Thing` in the call of `local: Thing = Thing(key)` with target kind `type`, and again with target kind `unknown`
- **THEN** the first is `new` and the second is `call`

#### Scenario: gr classifies Python class usages
- **WHEN** Neovim runs in a fresh copy of the extended `pyproj` fixture with the cursor on the `Money` declaration in `shop/money.py`, basedpyright and ruff attached, and `gr` is pressed in normal mode
- **THEN** the view lists exactly `shop/pricing.py:1` as `import`, `shop/pricing.py:3` as `new`, `shop/pricing.py:6` as `extends`, `shop/pricing.py:10` as `parameter_declaration`, and `tests/test_pricing.py:5` as `instanceof`

#### Scenario: Python class usages are grouped by usage type
- **WHEN** `gr` is pressed on the `Money` declaration in `shop/money.py` of the extended `pyproj` fixture with basedpyright and ruff attached, the editor at 70x24 and default grouping, and classification has finished
- **THEN** the screen matches the approved render "Proposed P1 — Python usage types of a class"

### Requirement: Lua usage types
The Lua `usages` query SHALL classify calls as `call`, names and `function` values of `function`, `local function`, `f = function`, `M.f = function` and `{ f = function }` as `function_declaration`, parameters as `parameter_declaration`, `{ name = … }` keys as `field_initialization`, assignment, `local` and loop targets as `write`, and other identifiers as `read`. Current-file write highlights that `gr` appends SHALL be classified like listed usages.

#### Scenario: Lua query classifies every usage type
- **WHEN** the Lua case table `tests/unit/references/usage_cases/lua.lua` (ported from `drafts/verify.lua`, ids renamed per design.md Decision 1) runs with the installed `lua` parser
- **THEN** every position gets its expected catalogue type, and every negative case gets no syntactic type

#### Scenario: gr classifies Lua function calls and redefinitions
- **WHEN** Neovim runs in a fresh copy of the extended `luaproj` fixture with `lua/shop/discount.lua` open, the cursor on `apply` in `function M.apply` (line 4), lua_ls attached, and `gr` is pressed in normal mode
- **THEN** the view lists `lua/shop/checkout.lua:3` as `call`, `lua/shop/discount.lua:9` (the `M.apply = function` redefinition, a current-file write highlight) as `function_declaration`, and `spec/discount_spec.lua:3` as `call`

#### Scenario: Lua usage types match the approved render
- **WHEN** `gr` is pressed on `apply` in `lua/shop/discount.lua` of the extended `luaproj` fixture with the editor at 70x24, default grouping and lua_ls attached, and classification has finished
- **THEN** the screen matches the approved render "Proposed L1 — Lua function usages"

### Requirement: Bash usage types
The Bash `usages` query SHALL classify command names as `call`, function definition names as `function_declaration`, a bare `export x` as `export`, targets of assignments, `declare`/`local`/`typeset`, `for`, `read` and `(( x++ ))` as `write`, and other variable names as `read`.

#### Scenario: Bash query classifies every usage type
- **WHEN** the Bash case table `tests/unit/references/usage_cases/shell.lua` (ported from `drafts/verify.lua`) runs with the installed `bash` parser
- **THEN** every position gets its expected catalogue type, and every negative case gets no syntactic type

#### Scenario: gr classifies Bash exports, writes and reads
- **WHEN** Neovim runs in a fresh copy of the extended `bashproj` fixture with `lib/tax.sh` open, the cursor on `rate` in `rate=20` (line 2), bashls attached, and `gr` is pressed in normal mode
- **THEN** the view lists `lib/tax.sh:3` as `export`, `lib/tax.sh:6` as `read` and `bin/invoice.sh:4` as `write`

#### Scenario: gr classifies Bash function usages as calls
- **WHEN** Neovim runs in a fresh copy of the `bashproj` fixture with `lib/price.sh` open, the cursor on the `total` function, bashls attached, and `gr` is pressed in normal mode
- **THEN** the view lists `bin/run.sh:4` and `test/price_test.sh:4` as `call`

#### Scenario: Bash usage types match the approved render
- **WHEN** `gr` is pressed on `rate` in `lib/tax.sh` of the extended `bashproj` fixture with the editor at 70x24, default grouping and bashls attached, and classification has finished
- **THEN** the screen matches the approved render "Proposed B1 — Bash variable usages"

### Requirement: Terraform usage types
The `hcl` `usages` query, inherited by `terraform`, SHALL classify `depends_on` traversals as `depends_on`, module, resource, data and local traversals in an `output` value (up to one level deep) as `output`, `module` block arguments as `attribute_assignment`, `module.`, `data.`, `local.` and resource traversals as their `*_reference` type, `locals` keys as `variable_declaration`, `variable` labels as `write` and `var.` traversals, in outputs too, as `read`.

#### Scenario: Terraform query classifies every usage type
- **WHEN** the Terraform case table `tests/unit/references/usage_cases/terraform.lua` (ported from `drafts/verify.lua`, ids renamed per design.md Decision 1) runs once with the installed `hcl` parser and once with `terraform`
- **THEN** both runs give every position its expected catalogue type, and every negative case gets no syntactic type

#### Scenario: gr classifies Terraform module variable usages
- **WHEN** Neovim runs in a fresh copy of the extended `tfproj` fixture, opens `network.tf` and then `net/main.tf`, places the cursor on `variable "cidr"` (line 1), terraform-ls is attached, and `gr` is pressed in normal mode
- **THEN** the view lists `network.tf:7` as `attribute_assignment`, and `net/main.tf:6` and `net/main.tf:10` (an input variable in an output value) as `read`

#### Scenario: gr classifies Terraform module usages
- **WHEN** Neovim runs in a fresh copy of the extended `tfproj` fixture with `network.tf` open, the cursor on `module "vpc"` (line 5), terraform-ls attached, and `gr` is pressed in normal mode
- **THEN** the view lists `network.tf:11` as `module_reference`, `network.tf:12` as `depends_on` and `network.tf:16` as `output`

#### Scenario: Terraform usage types match the approved render
- **WHEN** `gr` is pressed on `module "vpc"` in `network.tf` of the extended `tfproj` fixture with the editor at 70x24, default grouping and terraform-ls attached, and classification has finished
- **THEN** the screen matches the approved render "Proposed H1 — Terraform module usages"
