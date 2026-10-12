# Proposal

## Why

The opt-in `gui` layer pressed keys with osascript System Events, needed Accessibility for the calling terminal, stole focus and covered only four shortcuts. Keys without an Alacritty `chars` binding (Ctrl+Return, Ctrl+H/L/Q, Ctrl+arrows), `option_as_alt` and Cmd chords were only ever checked as bytes the stack layer assumes Alacritty sends.

## What Changes

- **BREAKING (tests only)**: the `gui` layer and `make e2e-gui` are removed; `tests/e2e/` replaces them (`make e2e`).
- The e2e layer launches a dedicated Alacritty instance (repo config, no activation), zellij and Neovim, and posts real key events to its pid (`CGEventPostToPid`, tests/e2e/keys.swift). It skips with a one-line fix when Accessibility is not granted.
- The new requirement "Real key presses in Alacritty deliver shortcuts" covers every shortcut table row that reaches Neovim, consumed shortcuts, Ctrl+Return, split and pane navigation, Ctrl+Up and Ctrl+Q.

## Capabilities

### New Capabilities

### Modified Capabilities

- `shortcuts`: requirement "Real Alacritty delivers shortcuts" (gui layer) is replaced by "Real key presses in Alacritty deliver shortcuts" (e2e layer).

## Impact

Tests and Makefile only (tests/e2e/, tests/shortcuts/stack.lua, tests/check.sh, tests/quick.sh, .archon/scripts/gate.py). No plugin dependency change. No core keymap change. Out of scope: changing any shortcut or terminal config, Linux support, screenshot checks of the Alacritty window.
