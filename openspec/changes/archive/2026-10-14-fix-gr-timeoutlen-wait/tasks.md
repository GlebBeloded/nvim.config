## 1. Make the global gr mapping unambiguous
Scenarios: `keymaps: gr bound to Telescope references`
- [x] 1.1 Write the test `keymaps: gr bound to Telescope references` in tests/integration/keymaps/test_keymaps.lua (or run it, if it exists) and see it fail
- [x] 1.2 Remove Neovim's conflicting default normal-mode `gr*` mappings after setup while preserving the configured `gr` Telescope mapping
- [x] 1.3 Run `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="gr bound to Telescope references"` and see it pass
