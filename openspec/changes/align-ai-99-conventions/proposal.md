## Why
The 99 entry mappings intentionally kept their old behavior during `refactor-ai-99-config`, but they
still violate the current conventions: they are not `silent`, visual mappings use `v` and therefore
also affect select mode, and `gleb.ai` requires 99 without tolerating a missing optional plugin.

Kind: bug

## What Changes
- Give all four 99 entry mappings `silent = true`.
- Register the two visual-selection mappings in `x` mode only, leaving select mode unmapped.
- Make `require("gleb.ai").setup()` return cleanly when 99 is unavailable.

## Capabilities
### Modified Capabilities
- `ai`: specify silent entry mappings, select-mode behavior, and missing-plugin tolerance.

## Impact
- Code: `lua/gleb/ai/init.lua`, `lua/gleb/ai/entry_keymaps.lua`, and AI tests.
- Plugins: none added, removed, or upgraded.
- Core keymaps: unchanged; two 99 feature mappings stop applying in select mode.
- Out of scope: splitting `ai/init.lua` further; it only wires the feature parts in the order recorded
  by the accepted `refactor-ai-99-config` design.
