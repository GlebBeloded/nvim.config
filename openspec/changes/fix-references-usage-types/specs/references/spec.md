## RENAMED Requirements

- FROM: `### Requirement: Usage kind classification`
- TO: `### Requirement: Usage type classification`

## MODIFIED Requirements

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

### Requirement: Asynchronous classification
The view SHALL open with scope and folder grouping as soon as references arrive, show `Usages of <symbol> · <count> · classifying` in its title while classification runs (at most 3 seconds), and rebuild with the usage type level when it finishes, keeping the selected usage.

#### Scenario: The view opens before classification finishes
- **WHEN** `gr` is pressed on `Calls` with documentHighlight responses delayed by a test hook
- **THEN** the view is open with title `Usages of Calls · 4 · classifying` and no usage type rows, and after the responses arrive the title is `Usages of Calls · 4` with `Value read` and `Value write` rows and the same selected usage

#### Scenario: Classification gives up after the timeout
- **WHEN** documentHighlight never answers for a file
- **THEN** after 3 seconds the title drops `· classifying`, the remaining usages are classified by the query and its fallback, and nothing is reported as an error

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

## ADDED Requirements

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

## REMOVED Requirements

### Requirement: Read/write grouping
**Reason**: Replaced by "Usage type grouping": write and read are now two of the catalogue's usage types, and functions get `Call` instead of no level.
**Migration**: `Value write` and `Value read` keep their icons and colours as usage type groups, sorted by label; the K1 render is refreshed.

### Requirement: Read/write toggle
**Reason**: Replaced by "Usage type toggle" on `u` (`references.toggle_usage_type`), which hides or shows the whole usage type level.
**Migration**: A persisted `read_write` state is read as `usage_type` once; `w` is no longer mapped in the view.
