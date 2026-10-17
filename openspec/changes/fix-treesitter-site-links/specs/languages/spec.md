## ADDED Requirements

### Requirement: Parser installs stay valid
A Neovim started under the test sandbox SHALL NOT create, change or remove anything in the host's `site` directory; there the parser installer SHALL NOT run, and missing configured parsers SHALL be named in one WARN. On every start, a `site/queries/<lang>` symlink whose target is missing or outside the installed nvim-treesitter's `runtime/queries` SHALL be relinked to `<nvim-treesitter>/runtime/queries/<lang>` when that exists, with one INFO naming the languages.

#### Scenario: A test child leaves the host site untouched
- **WHEN** a child is started with the test helpers' sandbox and the full config, and the configured parser list holds a parser the host `site` lacks
- **THEN** the names, symlink targets and modification times of every entry under the host `site` directory equal those before the child started, and the child's messages hold one WARN naming the missing parser

#### Scenario: A dangling query link is repaired on start
- **WHEN** a temporary `site/queries/hcl` is a symlink to a path that does not exist and the repair runs with that `site` directory
- **THEN** `site/queries/hcl` is a symlink to `<nvim-treesitter>/runtime/queries/hcl` and one INFO names `hcl`

#### Scenario: A query link outside the plugin is repaired
- **WHEN** a temporary `site/queries/hcl` is a symlink to an existing directory outside the installed nvim-treesitter and the repair runs
- **THEN** it now points at `<nvim-treesitter>/runtime/queries/hcl`

#### Scenario: Valid links and real folders are left alone
- **WHEN** the repair runs over a temporary `site/queries` holding a correct `go` link and a real `custom` directory
- **THEN** both are unchanged and no message is shown
