## Why
Augroup `99PromptKeymaps` (`lua/gleb/ai/prompt_keymaps.lua:11`) breaks rule 4.4 of `docs/architecture.md` (augroups are `gleb_<feature>[_<purpose>]`). The `ai` spec pins the name in the "Prompt submit keymap" requirement and its scenario, so `cleanup-convention-targets` (no spec delta) leaves it.

Kind: bug

## What Changes
- Rename the augroup to `gleb_ai_prompt_keymaps`.
- `ai` spec delta: the requirement and the scenario that name `99PromptKeymaps` use the new name; `tests/unit/ai/test_prompt_keymaps.lua` follows.

## Capabilities
### Modified Capabilities
- `ai`: augroup name in the prompt submit keymap requirement.

## Impact
- Code: `lua/gleb/ai/prompt_keymaps.lua`, `tests/unit/ai/test_prompt_keymaps.lua`, `openspec/specs/ai/spec.md`.
- Plugins: none added, removed or upgraded.
- Core keymaps: unchanged.
- Out of scope: the 99 inline config and `pi_provider` (`refactor-ai-99-config`); other augroup renames (`cleanup-convention-targets`).
