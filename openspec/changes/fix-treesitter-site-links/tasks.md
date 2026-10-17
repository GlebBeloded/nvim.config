## 1. Repair query links

Scenarios: `languages: A dangling query link is repaired on start`, `languages: A query link outside the plugin is repaired`, `languages: Valid links and real folders are left alone`

- [ ] 1.1 Write the three scenarios in tests/unit/languages/test_site_repair.lua on a temporary `site` dir, and see them fail
- [ ] 1.2 Add the repair (design Decision 2) and call it once at startup before the installer
- [ ] 1.3 Run `make test FILE=tests/unit/languages/test_site_repair.lua` and see them pass

## 2. No installs from test children

Scenarios: `languages: A test child leaves the host site untouched`, `languages: Installed parsers are unchanged`

- [ ] 2.1 Write the scenario in tests/integration/languages/test_site_isolation.lua: snapshot the host `site` tree (names, link targets, mtimes), start a sandboxed child with an extra parser in its list, compare. See it fail.
- [ ] 2.2 Skip the installer under the test sandbox and WARN on missing parsers (design Decision 1); keep the parser list unchanged
- [ ] 2.3 Run the file and `make check`; then start Neovim once normally and confirm `~/.local/share/nvim/site/queries/hcl` points into `~/.local/share/nvim/lazy/nvim-treesitter/runtime/queries/hcl`
