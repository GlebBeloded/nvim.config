## 1. Repair query links

Scenarios: `languages: A dangling query link is repaired on start`, `languages: A query link outside the plugin is repaired`, `languages: Valid links and real folders are left alone`

- [x] 1.1 Write the three scenarios in tests/unit/languages/test_site_repair.lua on a temporary `site` dir, and see them fail
- [x] 1.2 Add the repair (design Decision 2) and call it once at startup before the installer
- [x] 1.3 Run `make test FILE=tests/unit/languages/test_site_repair.lua` and see them pass

## 2. No installs from test children

Scenarios: `languages: A test child leaves the host site untouched`, `languages: Installed parsers are unchanged`

- [x] 2.1 Write the scenario in tests/integration/languages/test_site_isolation.lua: snapshot the host `site` tree (names, link targets, mtimes), start a sandboxed child with an extra parser in its list, compare. See it fail.
- [x] 2.2 Skip the installer under the test sandbox and WARN on missing parsers (design Decision 1); keep the parser list unchanged
- [x] 2.3 Run the file and `make check`; then start Neovim once normally and confirm `~/.local/share/nvim/site/queries/hcl` points into `~/.local/share/nvim/lazy/nvim-treesitter/runtime/queries/hcl`

## Agent decisions

- Set `GLEB_TEST_SANDBOX=1` in the shared isolation helper so every sandboxed child inherits one explicit startup guard.
- Check containment against the normalized raw symlink target; resolving it first hides temporary aliases that the repair must replace.
