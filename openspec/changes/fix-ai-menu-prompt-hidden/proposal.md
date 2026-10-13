## Why
The `<A-9>` menu waits for one key, but its prompt is hidden by the configured `cmdheight = 0`. The bottom row keeps showing the statusline while Neovim waits, so the menu gives no visible choices. The existing `ai: Menu shows prompt` integration case is `H.xfail` until this lands.

Kind: bug

## Root Cause
`normal_menu()` echoes the prompt and immediately blocks in `getcharstr()`. With `cmdheight = 0`, the echo has no message row to occupy before the blocking read; the later redraw happens only after a key arrives. The prompt is recorded as a message but is not drawn while input is pending.

## What Changes
- Temporarily provide one command-line row while the menu echoes its prompt and waits for a key, then restore the previous `cmdheight` before dispatching the choice.
- Remove the `H.xfail` from `ai: Menu shows prompt`.

## Decision
Keep the existing one-key message-area menu. Temporarily raising `cmdheight` preserves its text, highlight, key flow, and existing specification without adding a float or changing the interaction to `vim.ui.select`. Restoration is scoped to the menu invocation; the global configured value remains unchanged.

## Capabilities
### Modified Capabilities
- `ai`: require the menu prompt to remain visible while the one-key menu waits, including when `cmdheight` starts at zero.

## Impact
- Code: `lua/gleb/ai/entry_keymaps.lua`; `tests/integration/ai/test_prompt_keys.lua`.
- Plugins: none added, removed or upgraded.
- Core keymaps: unchanged.
- Out of scope: other `getchar()` prompts; changing `cmdheight` globally.
