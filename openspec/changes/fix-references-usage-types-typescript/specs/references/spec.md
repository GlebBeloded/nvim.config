## ADDED Requirements

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
