# Spec Delta

## MODIFIED Requirements

### Requirement: Usage kind classification
Every usage listed by `gr` SHALL be `write`, `read` or `other`. Server kinds SHALL take precedence; current-file write highlights omitted from references SHALL be added except at the origin. Remaining variable write targets and reads SHALL use treesitter when its parser is installed, including HCL variable labels and traversals. Without a parser they SHALL be `other`. Functions, methods and constructors SHALL remain `other`.

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
- **THEN** no error is raised and the usage is `other`

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
