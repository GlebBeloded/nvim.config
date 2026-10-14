## Why
The code-action popup (`lua/gleb/select/code_action.lua`, `rg -n longest_entry_length lua/gleb/select`) is always 255 columns wide (`longest_entry_length()` returns a hard-coded 255; `max_width = 20` has no effect), so on an 80-column screen the title and right border are off-screen and the menu covers the whole width.
Found by the second audit of auto (2026-10-14).

Kind: bug

## Evidence
- Confirmed in a headless full-config child by the audit; locate code with `rg -n` (line numbers may drift).

## What Changes
- Size the popup to the widest formatted item / prompt (`vim.fn.strdisplaywidth`) plus padding, capped at `vim.o.columns - 4`; keep everything else as is. This repairs a broken render (border off-screen), not a new look.
- `select` scenario for the width rule; test on an 80-column child with short and long items, RED first.
- Also (review note, run f082e845): the select cancel case (`tests/unit/select/test_code_action.lua`) calls `menu.on_close()` directly; make it press `<Esc>` in the mounted menu as its scenario says, keeping the `on_choice(nil, nil)` assertion.

## Capabilities
### Modified Capabilities
- `select`: scenarios for the fixed behaviour.

## Impact
- Code: the files named above and their tests.
- Plugins: none added or upgraded. Core keymaps: unchanged.
