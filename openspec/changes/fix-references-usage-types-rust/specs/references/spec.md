## ADDED Requirements

### Requirement: Rust usage types
Rust usages SHALL be classified by the `usages` query of parser `rust` with catalogue ids: import, macro calls and arguments, impl heads, trait bounds, struct and field initialization, patterns, calls, field access, field writes, and field, parameter, return, variable, alias, cast and generic argument types. A path qualifier SHALL take the type of its whole path, and macro token trees SHALL be classified on the top-level tree.

#### Scenario: Rust query classifies every usage type
- **WHEN** the Rust `usages` query classifies each position of the case table `tests/unit/references/usage_cases/rust.lua` in its source `usage_cases/rust/usages.rs` with the installed `rust` parser and the case's target kind
- **THEN** every position gets its expected catalogue id (`trait_bound` is `type_constraint`, `method_call` is `call`, `dot` is `field_access`, `trait_impl` is `extends`, `type_argument` is `type_instantiation`), a field assignment target is `write`, and every negative case gets no syntactic type

#### Scenario: gr classifies Rust struct usages
- **WHEN** Neovim runs in a fresh copy of the extended `rustproj` fixture with the cursor on the `Money` declaration in `src/money.rs`, rust-analyzer attached and quiescent, and `gr` is pressed in normal mode
- **THEN** the view lists `src/ledger.rs:1` and `tests/money.rs:1` as `import`, `src/ledger.rs:4` and `src/money.rs:7` as `return_type`, `src/ledger.rs:5` and `tests/money.rs:5` as `call`, `src/ledger.rs:9` as `parameter_declaration`, `src/ledger.rs:11` as `pattern`, `src/money.rs:6` as `impl` and `src/money.rs:8` as `struct_initialization`

#### Scenario: gr classifies Rust field usages
- **WHEN** Neovim runs in a fresh copy of the extended `rustproj` fixture with the cursor on the `cents` field declaration in `src/money.rs`, rust-analyzer attached and quiescent, and `gr` is pressed in normal mode
- **THEN** the view lists `src/ledger.rs:11` as `pattern`, `src/money.rs:8` as `field_initialization` and `tests/money.rs:6` as `macro_argument`

#### Scenario: Rust struct usages are grouped by usage type
- **WHEN** `gr` is pressed on the `Money` declaration in `src/money.rs` of the extended `rustproj` fixture with rust-analyzer attached, the editor at 70x36 and default grouping, and classification has finished
- **THEN** the screen matches the approved render "Proposed R1 — usage types of a Rust struct"
