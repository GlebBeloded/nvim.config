# Spec Delta

## MODIFIED Requirements

### Requirement: Parser installs stay valid
Under the test sandbox, Neovim SHALL leave the host `site` directory unchanged, skip parser installation, and name missing configured parsers in one WARN. On every start, invalid `site/queries/<lang>` links SHALL be relinked to the installed nvim-treesitter query when it exists, with one INFO naming repaired languages. A replacement failure SHALL produce one WARN naming the link and error, without stopping startup or repair of other links.

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

#### Scenario: An unwritable query link does not break startup
- **WHEN** replacement of one invalid query link fails with a filesystem error while another invalid link can be replaced
- **THEN** startup continues, the failed link is reported once at WARN with its path and error, and the other link is repaired
