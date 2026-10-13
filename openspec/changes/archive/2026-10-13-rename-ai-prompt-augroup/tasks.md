# Tasks

## 1. Rename the prompt keymap augroup
Scenarios: `ai: Setup is idempotent`
- [x] 1.1 Update the test `ai: Setup is idempotent` in tests/unit/ai/test_prompt_keymaps.lua to query `gleb_ai_prompt_keymaps` and see it fail
- [x] 1.2 Rename the augroup in lua/gleb/ai/prompt_keymaps.lua to `gleb_ai_prompt_keymaps`
- [x] 1.3 Run `make test FILE=tests/unit/ai/test_prompt_keymaps.lua CASE="Setup is idempotent"` and see it pass
