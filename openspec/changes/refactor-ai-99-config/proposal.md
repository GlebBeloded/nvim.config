## Why
The 99 setup, one-key menu and entry keymaps are an anonymous `config` function inline in `lua/gleb/plugins/plugins.lua:323-358`, not in `lua/gleb/ai/`, so they can't be unit-tested. The model string `openai-codex/gpt-5.6-sol` is hard-coded twice (`plugins.lua:327`, `lua/gleb/ai/pi_provider.lua:23`). `pi_provider.lua:1` requires `99` at module load, so the pure command-building logic can only be loaded after 99 is on the runtime path.

Kind: bug

## What Changes
- Move the 99 `config` body (setup call, `enter_prompt`, `normal_menu`, `vibe_prompt`, `visual_prompt`, entry keymaps) into a named module in `lua/gleb/ai/` (e.g. `lua/gleb/ai/init.lua` with `M.setup()`); the lazy spec's `config` calls it.
- Define the model once (e.g. `M.model` in the provider or an `ai` config table) and use it for both `nn.setup({ model = ... })` and `_get_default_model()`.
- `pi_provider.lua` resolves `require("99").Providers.BaseProvider` lazily (e.g. in the metatable `__index` function), so `_build_command`, `_get_provider_name` and `_get_default_model` work without 99 loaded.
- No behaviour change: same keys, descs, menu text, provider command and model.

## Capabilities
### Modified Capabilities
None (the `ai` spec requirements stay as they are; `skip_specs: true`).

## Impact
- Code: `lua/gleb/plugins/plugins.lua`, `lua/gleb/ai/pi_provider.lua`, new module under `lua/gleb/ai/`, `tests/ai/`.
- Plugins: none added, removed or upgraded.
- Core keymaps: unchanged.
- Out of scope: sharing the model with the Ollama commit model in `lua/gleb/git/ai_commit.lua:41`; migrating `tests/ai/*_spec.lua` from plenary to mini.test; the `param-type-mismatch` hit on `plugins.lua:338`, unless the move fixes it.
