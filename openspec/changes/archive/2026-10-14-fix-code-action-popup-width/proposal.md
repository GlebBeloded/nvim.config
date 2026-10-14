## Why
The code-action popup (`lua/gleb/select/code_action.lua`, `rg -n longest_entry_length lua/gleb/select`) is always 255 columns wide (`longest_entry_length()` returns a hard-coded 255; `max_width = 20` has no effect), so on an 80-column screen the title and right border are off-screen and the menu covers the whole width.
Found by the second audit of auto (2026-10-14).

Kind: bug

## Evidence
- `lua/gleb/select/code_action.lua:33` returns the constant width `255`, and `lua/gleb/select/code_action.lua:46` passes it as the popup's explicit width.
- `/Users/hlebbeladzed/.local/share/nvim/lazy/nui.nvim/lua/nui/menu/init.lua:252` computes the menu's `max_width`, but line 256 force-merges the explicit popup options over that default, so the configured width of `255` wins.

## What Changes
- Size the popup to the widest formatted item / prompt (`vim.fn.strdisplaywidth`) plus padding, capped at `vim.o.columns - 4`; keep everything else as is. This repairs a broken render (border off-screen), not a new look.
- `select` scenario for the width rule; test on an 80-column child with short and long items, RED first.
- Also (review note, run f082e845): the select cancel case (`tests/unit/select/test_code_action.lua`) calls `menu.on_close()` directly; make it press `<Esc>` in the mounted menu as its scenario says, keeping the `on_choice(nil, nil)` assertion.

## Capabilities
### Modified Capabilities
- `select`: scenarios for the fixed behaviour.

## Impact
- Code: `lua/gleb/select/code_action.lua` and `tests/unit/select/test_code_action.lua`.
- Plugins: none added or upgraded. Core keymaps: unchanged.
- Out of scope: changing picker contents, placement, border style, mappings, or selection callback semantics.
- `select: Selection accepts omitted options` still holds because the change only sizes code-action popups after dispatch and does not alter option normalization.
- `select: Cancelling a code action completes selection` still holds; its test will exercise the existing `<Esc>` path through the mounted menu instead of invoking `on_close` directly.
