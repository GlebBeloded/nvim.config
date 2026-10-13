## 1. Keep the 99 menu prompt visible while waiting
Scenarios: `ai: Menu shows prompt`
- [x] 1.1 Remove the `H.xfail` wrapper from the existing test `ai: Menu shows prompt` in `tests/integration/ai/test_prompt_keys.lua`, run it, and see it fail with the statusline still occupying the bottom row
- [x] 1.2 In `lua/gleb/ai/entry_keymaps.lua`, temporarily provide one command-line row around the menu echo and key read, then restore the prior `cmdheight` before dispatching the selected action
- [x] 1.3 Run `make test FILE=tests/integration/ai/test_prompt_keys.lua CASE="Menu shows prompt"` and see it pass
- [x] 1.4 Run `make quick`
- [x] 1.5 Run `make check`
