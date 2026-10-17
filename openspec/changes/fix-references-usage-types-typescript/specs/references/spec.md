## MODIFIED Requirements

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

#### Scenario: TypeScript class usages are grouped by usage type
- **WHEN** `gr` is pressed on the `Money` declaration in `src/money.ts` of the extended `tsproj` fixture with vtsls attached, the editor at 70x50 and default grouping, and classification has finished
- **THEN** the screen matches the approved render "Proposed P1 — TypeScript usage types of a class"
