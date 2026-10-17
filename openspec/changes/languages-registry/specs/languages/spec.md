## Purpose
Keeps everything the config knows about a programming language in one typed module per language, and makes every feature that needs per-language support declare it as a facet that each language must answer.

## ADDED Requirements

### Requirement: One module per language
Each configured language SHALL be one folder `lua/gleb/languages/<name>/` whose `init.lua` returns a language spec: its name, filetypes and one entry per registered facet. The registry SHALL discover every such folder without a hand-kept list, and SHALL resolve a filetype to its language.

#### Scenario: Every configured language is registered
- **WHEN** the full config is loaded and the registry's languages are listed
- **THEN** their names are `css`, `go`, `html`, `js`, `json`, `lua`, `python`, `rust`, `shell`, `terraform` and `yaml`, in that order

#### Scenario: A filetype resolves to its language
- **WHEN** the registry is asked for the languages of filetypes `typescriptreact`, `sh`, `tf` and `gomod`
- **THEN** it returns `js`, `shell`, `terraform` and `go`

#### Scenario: A new language folder is discovered
- **WHEN** a test adds a runtimepath folder holding `lua/gleb/languages/zig/init.lua` with a complete spec and the registry is reset
- **THEN** the registry lists `zig` without any other file changing

### Requirement: Features declare facets every language answers
A feature that needs per-language data SHALL register a named facet with a validator. Every language SHALL answer every registered facet with a configuration or `{ disabled = "<reason>" }` with a non-empty reason. Validation SHALL run at startup and raise an error naming the language and facet for a missing facet, an unknown facet key, an empty reason or a validator failure. The lsp, treesitter and references features SHALL register `lsp`, `treesitter` and `references`.

#### Scenario: Registered facets
- **WHEN** the full config is loaded and the registered facet names are listed
- **THEN** they are `lsp`, `references` and `treesitter`

#### Scenario: A language missing a facet fails at startup
- **WHEN** the registry validates a language spec `zig` that has no `references` entry
- **THEN** an error is raised whose message is `languages: zig lacks facet references`

#### Scenario: A disabled facet needs a reason
- **WHEN** the registry validates a spec whose `references` is `{ disabled = "" }`
- **THEN** an error is raised naming that language and `references`

#### Scenario: A new facet must be answered by every language
- **WHEN** a test registers a facet `testing` and validates the configured languages
- **THEN** the error names a language that lacks facet `testing`, and validation passes once every language answers it

### Requirement: Language facets drive LSP and treesitter setup
The lsp feature SHALL enable servers, install mason packages (`:MasonSync`) and add null-ls sources only from enabled `lsp` facets. The treesitter feature SHALL install the editor parsers (vim, vimdoc, markdown, markdown_inline) plus every enabled `treesitter` facet's parsers. The resulting servers, packages and parsers SHALL equal the configuration before the registry existed.

#### Scenario: Enabled LSP servers are unchanged
- **WHEN** the full config is loaded and the names passed to `vim.lsp.enable` are listed
- **THEN** they are exactly `cssls`, `gopls`, `html`, `vtsls`, `eslint`, `jsonls`, `lua_ls`, `basedpyright`, `ruff`, `bashls`, `terraformls` and `yamlls`

#### Scenario: Installed parsers are unchanged
- **WHEN** the full config is loaded and the parser list passed to the treesitter installer is read
- **THEN** it holds exactly bash, go, gomod, hcl, javascript, json, lua, markdown, markdown_inline, python, rust, terraform, tsx, typescript, vim, vimdoc and yaml

### Requirement: References facet
Test-file detection and usage classification SHALL take a language's test patterns, write-access source and symbol-kind overrides only from its enabled `references` facet, and the query parser language from the buffer filetype; a filetype without one SHALL use the generic test segments and server kinds only. A language with `usage_types = true` SHALL ship a `usages` query for each of its filetypes' parser languages and its own query case table.

#### Scenario: Test patterns come from the facet
- **WHEN** a test replaces the go language's `references.test_patterns` with `{ "_check%.go$" }` and resets the registry
- **THEN** `is_test("pkg/a_check.go", "go")` is true and `is_test("pkg/a_test.go", "go")` is false

#### Scenario: Terraform queries inherit the HCL query
- **WHEN** usages in a `terraform` buffer are classified
- **THEN** the `terraform` parser language's `usages` query is used, and its patterns are the `hcl` query's through `; inherits: hcl`

### Requirement: Language contract
A unit test SHALL check every registered language against the contract: each enabled facet passes its validator, its parsers are installed, and its `usages` query compiles and captures only catalogue ids. Its case table SHALL exist, and its fixture project and manifest symbol SHALL exist in the fixture builder. A disabled reason `queued: <id>` SHALL name an existing change. The references integration suite SHALL run `gr` once per enabled `references` facet on its fixture.

#### Scenario: Every configured language meets the contract
- **WHEN** the contract check runs over every registered language
- **THEN** it reports no problems

#### Scenario: A missing usages query breaks the contract
- **WHEN** the contract check runs on a language spec with `references.usage_types = true` and a filetype whose parser language has no `usages` query
- **THEN** it reports `<name>: references.usage_types needs queries/<lang>/usages.scm`

#### Scenario: A missing fixture breaks the contract
- **WHEN** the contract check runs on a language spec whose `references.fixture.project` is not a fixture builder case
- **THEN** it reports `<name>: references.fixture.project <project> is not in tests/fixtures/build.sh`

#### Scenario: A stale queued reason breaks the contract
- **WHEN** the contract check runs on a facet `{ disabled = "queued: no-such-change" }`
- **THEN** it reports `<name>: queued change no-such-change does not exist`

#### Scenario: Each references facet gets a gr run
- **WHEN** the references language suite is listed
- **THEN** it has one case per language with an enabled `references` facet, named after that language, each opening the facet's fixture and running `gr` on the facet's symbol
