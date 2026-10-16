## 1. Path conventions per language
Scenarios: `references: Language conventions classify paths`, `references: Production paths are not test code`, `references: Unknown languages use the generic segments`, `references: A project adds its own test pattern`
- [ ] 1.1 Write the four scenarios in tests/unit/references/test_scope.lua and see them fail
- [ ] 1.2 Add `lua/gleb/references/scope.lua`. It holds the pure per-filetype pattern table (filetype taken from `vim.filetype.match({ filename = path })` when none is given), the generic segment rule, and the `vim.g.gleb_test_patterns` extension. The module has LuaCATS types.
- [ ] 1.3 Run `make test FILE=tests/unit/references/test_scope.lua` and see all four pass

## 2. Rust inline test modules
Scenarios: `references: A usage inside a cfg(test) module is test code`, `references: Missing rust parser falls back to paths`
- [ ] 2.1 Write both scenarios in tests/unit/references/test_scope.lua. Stub parser availability so the scenario passes whether or not the host has the parser. See them fail.
- [ ] 2.2 Add `is_test_at(path, lnum, text)`. It parses the given text with `vim.treesitter.get_string_parser(text, "rust")` inside `pcall`, and walks up to a `mod_item` whose attribute is `cfg(test)`.
- [ ] 2.3 Run the file and see both pass, then `make check`
